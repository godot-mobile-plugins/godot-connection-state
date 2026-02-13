//
// © 2025-present https://github.com/cengiz-pz
//

import Foundation
import Network

@objc public class ConnectionState: NSObject {

	// Callbacks to be set by the Objective-C bridge
	@objc public var onConnectionEstablished: ((_ info: [String: Any]) -> Void)?
	@objc public var onConnectionLost: ((_ info: [String: Any]) -> Void)?

	// Default monitor for tracking the primary "Active" internet connection
	private let defaultMonitor = NWPathMonitor()

	// Specific monitors to track availability of different interface types
	private let wifiMonitor = NWPathMonitor(requiredInterfaceType: .wifi)
	private let cellularMonitor = NWPathMonitor(requiredInterfaceType: .cellular)
	private let ethernetMonitor = NWPathMonitor(requiredInterfaceType: .wiredEthernet)

	private let queue = DispatchQueue(label: "ConnectionState")

	// State tracking for the default (active) path
	private var isDefaultConnected = false
	private var lastDefaultInfo: [String: Any]?

	// State tracking for specific interfaces
	private var isWifiConnected = false
	private var lastWifiInfo: [String: Any]?

	private var isCellularConnected = false
	private var lastCellularInfo: [String: Any]?

	private var isEthernetConnected = false
	private var lastEthernetInfo: [String: Any]?

	@objc static let isActiveKey = "is_active"
	@objc static let connectionTypeKey = "connection_type"
	@objc static let isMeteredKey = "is_metered"

	override init() {
		super.init()
		startMonitoring()
	}

	func startMonitoring() {
		// Default monitor (active)
		defaultMonitor.pathUpdateHandler = { [weak self] path in
			self?.handleDefaultUpdate(path)
		}
		defaultMonitor.start(queue: queue)

		// Specific monitors
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

	// Internal State Helpers

	private func getInternalState(for type: NWInterface.InterfaceType) -> (isConnected: Bool, lastInfo: [String: Any]?) {
		switch type {
		case .wifi: return (isWifiConnected, lastWifiInfo)
		case .cellular: return (isCellularConnected, lastCellularInfo)
		case .wiredEthernet: return (isEthernetConnected, lastEthernetInfo)
		default: return (false, nil)
		}
	}

	private func setInternalState(for type: NWInterface.InterfaceType, isConnected: Bool, lastInfo: [String: Any]?) {
		switch type {
		case .wifi:
			self.isWifiConnected = isConnected
			self.lastWifiInfo = lastInfo
		case .cellular:
			self.isCellularConnected = isConnected
			self.lastCellularInfo = lastInfo
		case .wiredEthernet:
			self.isEthernetConnected = isConnected
			self.lastEthernetInfo = lastInfo
		default: return
		}
	}

	// Update Handlers

	private func handleDefaultUpdate(_ path: NWPath) {
		let isSatisfied = path.status == .satisfied
		var info: [String: Any]

		if isSatisfied {
			// Overall connection established - use path info and cache it
			info = getPathInfo(path)
			info[Self.isActiveKey] = true
			lastDefaultInfo = info
		} else {
			// Overall connection lost - use cached info if available to identify what was lost
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
		// to keep `getCurrentState` coherent
		updateSpecificInterfaceStates()
	}

	// Update the specific monitor states based on the current path status
	private func updateSpecificInterfaceStates() {
		let monitors: [(NWPathMonitor, NWInterface.InterfaceType)] = [
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

				// Update state
				setInternalState(for: type, isConnected: true, lastInfo: info)

			} else if !isSatisfied && wasConnected {
				// Connection lost
				var info: [String: Any]
				if let cached = currentState.lastInfo {
					info = cached
				} else {
					info = getPathInfo(path)
				}
				info[Self.isActiveKey] = false

				// Commit state change
				setInternalState(for: type, isConnected: false, lastInfo: nil)

				// Only emit if it was NOT the active path before the loss as `handleDefaultUpdate` already handled the primary signal
				if !wasActive {
					onConnectionLost?(info)
				}
			}
		}
	}

	private func handleSpecificUpdate(path: NWPath,
									interfaceType: NWInterface.InterfaceType) {
		
		let isSatisfied = path.status == .satisfied
		let currentState = getInternalState(for: interfaceType)
		let wasConnected = currentState.isConnected
		let wasActive = currentState.lastInfo?[Self.isActiveKey] as? Bool ?? false
		
		if !isSatisfied && wasConnected {
			// Connection lost
			var info: [String: Any]
			if let cached = currentState.lastInfo {
				info = cached
			} else {
				info = getPathInfo(path)
			}
			info[Self.isActiveKey] = false

			// Commit state change
			setInternalState(for: interfaceType, isConnected: false, lastInfo: nil)

			// On LOST: Only emit if it was NOT the active path immediately before the loss
			if !wasActive {
				onConnectionLost?(info)
			}
		} else if isSatisfied {
			// If satisfied, update the internal state to reflect its new status (e.g., active/not active)
			// The signal emission is deferred to `handleDefaultUpdate` or `updateSpecificInterfaceStates`.
			let activePath = defaultMonitor.currentPath
			let isActivePath = activePath.usesInterfaceType(interfaceType)
			var info = getPathInfo(path)
			info[Self.isActiveKey] = isActivePath

			setInternalState(for: interfaceType, isConnected: true, lastInfo: info)
		}
	}

	// State Retrieval

	@objc public func getCurrentState() -> [[String: Any]] {
		var availableConnections: [[String: Any]] = []
		let activePath = defaultMonitor.currentPath

		// Helper to append info if satisfied
		func appendIfSatisfied(_ monitor: NWPathMonitor, type: NWInterface.InterfaceType) {
			if monitor.currentPath.status == .satisfied {
				var info = getPathInfo(monitor.currentPath)
				info[Self.isActiveKey] = activePath.usesInterfaceType(type)
				availableConnections.append(info)
			}
		}

		appendIfSatisfied(wifiMonitor, type: .wifi)
		appendIfSatisfied(cellularMonitor, type: .cellular)
		appendIfSatisfied(ethernetMonitor, type: .wiredEthernet)

		// Fallback for VPNs or other types caught by default monitor but not specific ones
		if availableConnections.isEmpty && activePath.status == .satisfied {
			var info = getPathInfo(activePath)
			info[Self.isActiveKey] = true
			availableConnections.append(info)
		}

		return availableConnections
	}

	private func getPathInfo(_ path: NWPath) -> [String: Any] {
		var type: ConnectionType = .unknown

		if path.usesInterfaceType(.wifi) { type = .wifi }
		else if path.usesInterfaceType(.cellular) { type = .cellular }
		else if path.usesInterfaceType(.wiredEthernet) { type = .ethernet }
		else if path.usesInterfaceType(.loopback) { type = .loopback }
		else if path.usesInterfaceType(.other) { type = .vpn }

		let isMetered = path.isExpensive

		return [
			Self.connectionTypeKey: type.rawValue,
			Self.isMeteredKey: isMetered
		]
	}

	deinit {
		defaultMonitor.cancel()
		wifiMonitor.cancel()
		cellularMonitor.cancel()
		ethernetMonitor.cancel()
	}
}
