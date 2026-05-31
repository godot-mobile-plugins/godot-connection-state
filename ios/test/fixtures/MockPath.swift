//
// © 2025-present https://github.com/cengiz-pz
//

@testable import connection_state_plugin
import Foundation
import Network

// MARK: - MockPath

/// A fully controllable stand-in for `NWPath`.
///
/// `NWPath` is a concrete struct created exclusively by the OS and cannot be
/// instantiated in test code.  `MockPath` conforms to `PathInterface` so it can
/// be passed anywhere `ConnectionState` expects a path without touching the real
/// Network framework.
///
/// Usage:
/// ```swift
/// // Pre-built factories cover the common cases:
/// let path = MockPath.wifi(metered: false)
/// let path = MockPath.disconnected
///
/// // The memberwise initialiser handles edge cases:
/// let path = MockPath(status: .satisfied, isExpensive: true, interfaceTypes: [.wifi, .cellular])
/// ```
struct MockPath: PathInterface {

	// MARK: PathInterface

	let status: NWPath.Status
	let isExpensive: Bool

	private let interfaceTypes: Set<NWInterface.InterfaceType>

	func usesInterfaceType(_ type: NWInterface.InterfaceType) -> Bool {
		interfaceTypes.contains(type)
	}

	// MARK: Initialisation

	/// - Parameters:
	///   - status:         The simulated satisfaction state. Defaults to `.satisfied`.
	///   - isExpensive:    Whether the connection is metered.  Defaults to `false`.
	///   - interfaceTypes: The set of interface types that `usesInterfaceType(_:)` reports as
	///                     active.  Pass an empty set (the default) to simulate an unclassified
	///                     or unknown path (reports `ConnectionType.unknown`).
	init(
		status: NWPath.Status = .satisfied,
		isExpensive: Bool = false,
		interfaceTypes: Set<NWInterface.InterfaceType> = []
	) {
		self.status = status
		self.isExpensive = isExpensive
		self.interfaceTypes = interfaceTypes
	}
}

// MARK: - Convenience factories

extension MockPath {

	/// A satisfied WiFi path.
	///
	/// - Parameter metered: `true` if the path should be considered metered (`isExpensive`).
	///                       Defaults to `false` as WiFi is typically unmetered.
	static func wifi(metered: Bool = false) -> MockPath {
		MockPath(status: .satisfied, isExpensive: metered, interfaceTypes: [.wifi])
	}

	/// A satisfied cellular path.
	///
	/// - Parameter metered: `true` if the path should be considered metered.
	///                       Defaults to `true` as cellular data is typically metered.
	static func cellular(metered: Bool = true) -> MockPath {
		MockPath(status: .satisfied, isExpensive: metered, interfaceTypes: [.cellular])
	}

	/// A satisfied wired Ethernet path.
	static func ethernet(metered: Bool = false) -> MockPath {
		MockPath(status: .satisfied, isExpensive: metered, interfaceTypes: [.wiredEthernet])
	}

	/// A satisfied loopback path.
	static func loopback() -> MockPath {
		MockPath(status: .satisfied, interfaceTypes: [.loopback])
	}

	/// A satisfied path using `NWInterface.InterfaceType.other`, which `ConnectionState`
	/// maps to `ConnectionType.vpn`.
	static func vpn() -> MockPath {
		MockPath(status: .satisfied, interfaceTypes: [.other])
	}

	/// A satisfied path with no recognised interface type — maps to `ConnectionType.unknown`.
	static func unknown() -> MockPath {
		MockPath(status: .satisfied, interfaceTypes: [])
	}

	/// An unsatisfied path, simulating a connection that is fully down.
	static var disconnected: MockPath {
		MockPath(status: .unsatisfied, interfaceTypes: [])
	}
}
