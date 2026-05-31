//
// © 2025-present https://github.com/cengiz-pz
//

import Foundation
import Network

// MARK: - PathInterface

/// Abstracts the observable properties of NWPath.
///
/// `NWPath` is a concrete struct created exclusively by the OS — it cannot be
/// instantiated in test code.  Introducing this protocol lets `ConnectionState`'s
/// private methods accept a fake implementation during XCTest runs while remaining
/// completely unchanged in production behaviour.
///
/// `NWPath` already exposes all three members, so the retroactive conformance below
/// requires no additional code.
protocol PathInterface {
	var status: NWPath.Status { get }
	var isExpensive: Bool { get }
	func usesInterfaceType(_ type: NWInterface.InterfaceType) -> Bool
}

extension NWPath: PathInterface {}

// MARK: - PathMonitorInterface

/// Abstracts `NWPathMonitor` so its concrete instances can be replaced with
/// controllable fakes in unit tests.
///
/// The `: AnyObject` constraint ensures conformers are reference types, which is
/// necessary for the settable `pathUpdateHandler` property to work correctly with
/// `any PathMonitorInterface` existentials.
protocol PathMonitorInterface: AnyObject {
	/// Invoked by the framework (or a test) each time the path changes.
	var pathUpdateHandler: ((any PathInterface) -> Void)? { get set }
	/// The most recently observed path snapshot.
	var currentPath: any PathInterface { get }
	func start(queue: DispatchQueue)
	func cancel()
}

// MARK: - PathMonitorAdapter

/// Wraps a concrete `NWPathMonitor` and bridges its `NWPath`-typed handler to the
/// `PathInterface`-typed one required by `PathMonitorInterface`.
///
/// This adapter is the only place that knows about real `NWPathMonitor` instances;
/// everywhere else inside `ConnectionState` works purely against the protocol.
final class PathMonitorAdapter: PathMonitorInterface {

	private let monitor: NWPathMonitor

	var pathUpdateHandler: ((any PathInterface) -> Void)? {
		didSet {
			monitor.pathUpdateHandler = { [weak self] path in
				// NWPath already conforms to PathInterface, so this cast is free.
				self?.pathUpdateHandler?(path)
			}
		}
	}

	var currentPath: any PathInterface { monitor.currentPath }

	init(_ monitor: NWPathMonitor) { self.monitor = monitor }

	func start(queue: DispatchQueue) { monitor.start(queue: queue) }
	func cancel() { monitor.cancel() }
}

// MARK: - ConnectionState

@objc public class ConnectionState: NSObject {

	// MARK: Callbacks (set by the Objective-C bridge)

	@objc public var onConnectionEstablished: ((_ info: [String: Any]) -> Void)?
	@objc public var onConnectionLost: ((_ info: [String: Any]) -> Void)?

	// MARK: Monitors

	private let defaultMonitor: any PathMonitorInterface
	private let wifiMonitor: any PathMonitorInterface
	private let cellularMonitor: any PathMonitorInterface
	private let ethernetMonitor: any PathMonitorInterface

	private let queue = DispatchQueue(label: "ConnectionState")

	// MARK: State – default path

	private var isDefaultConnected = false
	private var lastDefaultInfo: [String: Any]?

	// MARK: State – specific interfaces

	private var isWifiConnected = false
	private var lastWifiInfo: [String: Any]?

	private var isCellularConnected = false
	private var lastCellularInfo: [String: Any]?

	private var isEthernetConnected = false
	private var lastEthernetInfo: [String: Any]?

	// MARK: Dictionary keys

	@objc static let isActiveKey       = "is_active"
	@objc static let connectionTypeKey = "connection_type"
	@objc static let isMeteredKey      = "is_metered"

	// MARK: - Initialisation

	/// Production initialiser — wraps real `NWPathMonitor` instances via adapters.
	override init() {
		self.defaultMonitor  = PathMonitorAdapter(NWPathMonitor())
		self.wifiMonitor     = PathMonitorAdapter(NWPathMonitor(requiredInterfaceType: .wifi))
		self.cellularMonitor = PathMonitorAdapter(NWPathMonitor(requiredInterfaceType: .cellular))
		self.ethernetMonitor = PathMonitorAdapter(NWPathMonitor(requiredInterfaceType: .wiredEthernet))
		super.init()
		startMonitoring()
	}

	/// Testing initialiser — accepts pre-built monitor fakes.
	///
	/// Accessible from the test target via `@testable import`.  All four monitors
	/// are started immediately so that injected `pathUpdateHandler` closures are
	/// ready to receive simulated updates as soon as the object is constructed.
	init(
		defaultMonitor: any PathMonitorInterface,
		wifiMonitor: any PathMonitorInterface,
		cellularMonitor: any PathMonitorInterface,
		ethernetMonitor: any PathMonitorInterface
	) {
		self.defaultMonitor  = defaultMonitor
		self.wifiMonitor     = wifiMonitor
		self.cellularMonitor = cellularMonitor
		self.ethernetMonitor = ethernetMonitor
		super.init()
		startMonitoring()
	}

	// MARK: - Monitoring

	func startMonitoring() {
		defaultMonitor.pathUpdateHandler = { [weak self] path in
			self?.handleDefaultUpdate(path)
		}
		defaultMonitor.start(queue: queue)

		wifiMonitor.pathUpdateHandler = { [weak self] path in
			self?.handleSpecificUpdate(path: path, interfaceType: .wifi)
		}
		wifiMonitor.start(queue: queue)

		cellularMonitor.pathUpdateHandler = { [weak self] path in
			self?.handleSpecificUpdate(path: path, interfaceType: .cellular)
		}
		cellularMonitor.start(queue: queue)

		ethernetMonitor.pathUpdateHandler = { [weak self] path in
			self?.handleSpecificUpdate(path: path, interfaceType: .wiredEthernet)
		}
		ethernetMonitor.start(queue: queue)
	}

	// MARK: - Internal State Helpers

	private func getInternalState(
		for type: NWInterface.InterfaceType
	) -> (isConnected: Bool, lastInfo: [String: Any]?) {
		switch type {
		case .wifi:         return (isWifiConnected, lastWifiInfo)
		case .cellular:     return (isCellularConnected, lastCellularInfo)
		case .wiredEthernet: return (isEthernetConnected, lastEthernetInfo)
		default:            return (false, nil)
		}
	}

	private func setInternalState(
		for type: NWInterface.InterfaceType,
		isConnected: Bool,
		lastInfo: [String: Any]?
	) {
		switch type {
		case .wifi:
			isWifiConnected = isConnected
			lastWifiInfo    = lastInfo
		case .cellular:
			isCellularConnected = isConnected
			lastCellularInfo    = lastInfo
		case .wiredEthernet:
			isEthernetConnected = isConnected
			lastEthernetInfo    = lastInfo
		default:
			return
		}
	}

	// MARK: - Update Handlers

	private func handleDefaultUpdate(_ path: any PathInterface) {
		let isSatisfied = path.status == .satisfied
		var info: [String: Any]

		if isSatisfied {
			// Overall connection established — use path info and cache it.
			info = getPathInfo(path)
			info[Self.isActiveKey] = true
			lastDefaultInfo = info
		} else {
			// Overall connection lost — use cached info if available to identify what was lost.
			if let cached = lastDefaultInfo {
				info = cached
			} else {
				info = getPathInfo(path)
			}
			info[Self.isActiveKey] = false
		}

		if isSatisfied && !isDefaultConnected {
			isDefaultConnected = true
			onConnectionEstablished?(info)
		} else if !isSatisfied && isDefaultConnected {
			isDefaultConnected = false
			onConnectionLost?(info)
			lastDefaultInfo = nil
		}

		// Ensure specific interface states are updated after the default monitor has finished
		// to keep `getCurrentState` coherent.
		updateSpecificInterfaceStates()
	}

	// Update the specific monitor states based on the current path status.
	private func updateSpecificInterfaceStates() {
		let monitors: [(any PathMonitorInterface, NWInterface.InterfaceType)] = [
			(wifiMonitor, .wifi),
			(cellularMonitor, .cellular),
			(ethernetMonitor, .wiredEthernet)
		]

		for (monitor, type) in monitors {
			let path = monitor.currentPath
			let isSatisfied = path.status == .satisfied
			let currentState = getInternalState(for: type)
			let wasConnected = currentState.isConnected
			let wasActive = currentState.lastInfo?[Self.isActiveKey] as? Bool ?? false

			if isSatisfied {
				let activePath = defaultMonitor.currentPath
				let isActivePath = activePath.usesInterfaceType(type)
				var info = getPathInfo(path)
				info[Self.isActiveKey] = isActivePath

				setInternalState(for: type, isConnected: true, lastInfo: info)

			} else if !isSatisfied && wasConnected {
				var info: [String: Any]
				if let cached = currentState.lastInfo {
					info = cached
				} else {
					info = getPathInfo(path)
				}
				info[Self.isActiveKey] = false

				setInternalState(for: type, isConnected: false, lastInfo: nil)

				// Only emit if it was NOT the active path before the loss as
				// `handleDefaultUpdate` already handled the primary signal.
				if !wasActive {
					onConnectionLost?(info)
				}
			}
		}
	}

	private func handleSpecificUpdate(
		path: any PathInterface,
		interfaceType: NWInterface.InterfaceType
	) {
		let isSatisfied = path.status == .satisfied
		let currentState = getInternalState(for: interfaceType)
		let wasConnected = currentState.isConnected
		let wasActive = currentState.lastInfo?[Self.isActiveKey] as? Bool ?? false

		if !isSatisfied && wasConnected {
			var info: [String: Any]
			if let cached = currentState.lastInfo {
				info = cached
			} else {
				info = getPathInfo(path)
			}
			info[Self.isActiveKey] = false

			setInternalState(for: interfaceType, isConnected: false, lastInfo: nil)

			// On LOST: only emit if it was NOT the active path immediately before the loss.
			if !wasActive {
				onConnectionLost?(info)
			}
		} else if isSatisfied {
			// If satisfied, update the internal state to reflect its new status (e.g. active/not active).
			// Signal emission is deferred to `handleDefaultUpdate` or `updateSpecificInterfaceStates`.
			let activePath = defaultMonitor.currentPath
			let isActivePath = activePath.usesInterfaceType(interfaceType)
			var info = getPathInfo(path)
			info[Self.isActiveKey] = isActivePath

			setInternalState(for: interfaceType, isConnected: true, lastInfo: info)
		}
	}

	// MARK: - State Retrieval

	@objc public func getCurrentState() -> [[String: Any]] {
		var availableConnections: [[String: Any]] = []
		let activePath = defaultMonitor.currentPath

		// Helper to append info if satisfied
		func appendIfSatisfied(_ monitor: any PathMonitorInterface, type: NWInterface.InterfaceType) {
			if monitor.currentPath.status == .satisfied {
				var info = getPathInfo(monitor.currentPath)
				info[Self.isActiveKey] = activePath.usesInterfaceType(type)
				availableConnections.append(info)
			}
		}

		appendIfSatisfied(wifiMonitor, type: .wifi)
		appendIfSatisfied(cellularMonitor, type: .cellular)
		appendIfSatisfied(ethernetMonitor, type: .wiredEthernet)

		// Fallback for VPNs or other types caught by the default monitor but not the specific ones.
		if availableConnections.isEmpty && activePath.status == .satisfied {
			var info = getPathInfo(activePath)
			info[Self.isActiveKey] = true
			availableConnections.append(info)
		}

		return availableConnections
	}

	private func getPathInfo(_ path: any PathInterface) -> [String: Any] {
		var type: ConnectionType = .unknown

		if path.usesInterfaceType(.wifi) {
			type = .wifi
		} else if path.usesInterfaceType(.cellular) {
			type = .cellular
		} else if path.usesInterfaceType(.wiredEthernet) {
			type = .ethernet
		} else if path.usesInterfaceType(.loopback) {
			type = .loopback
		} else if path.usesInterfaceType(.other) {
			type = .vpn
		}

		return [
			Self.connectionTypeKey: type.rawValue,
			Self.isMeteredKey: path.isExpensive
		]
	}

	// MARK: - Deinit

	deinit {
		defaultMonitor.cancel()
		wifiMonitor.cancel()
		cellularMonitor.cancel()
		ethernetMonitor.cancel()
	}
}
