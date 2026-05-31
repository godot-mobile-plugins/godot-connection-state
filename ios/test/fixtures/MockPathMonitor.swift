//
// © 2025-present https://github.com/cengiz-pz
//

@testable import connection_state_plugin
import Foundation
import Network

// MARK: - MockPathMonitor

/// A controllable stand-in for `NWPathMonitor`.
///
/// Conforms to `PathMonitorInterface` so it can be injected into `ConnectionState`
/// via the testing initialiser.  All path-update delivery is **synchronous and
/// on the calling thread**, which eliminates async waiting and makes XCTest
/// assertions straightforward.
///
/// Usage:
/// ```swift
/// let monitor = MockPathMonitor()
///
/// // Pre-configure currentPath without firing handlers:
/// monitor.stubbedCurrentPath = MockPath.wifi()
///
/// // Simulate the OS delivering a new path (updates currentPath + fires handler):
/// monitor.simulate(path: .wifi())
/// monitor.simulateDisconnect()
///
/// // Inspect lifecycle:
/// XCTAssertTrue(monitor.didStart)
/// XCTAssertTrue(monitor.didCancel)
/// ```
final class MockPathMonitor: PathMonitorInterface {

	// MARK: - PathMonitorInterface

	var pathUpdateHandler: ((any PathInterface) -> Void)?

	/// The value returned by `currentPath`.
	///
	/// Tests may set this directly to pre-configure state **without** triggering
	/// the `pathUpdateHandler`.  `simulate(path:)` updates this property AND fires
	/// the handler, matching what the real `NWPathMonitor` does.
	var stubbedCurrentPath: any PathInterface

	var currentPath: any PathInterface { stubbedCurrentPath }

	// MARK: - Lifecycle observation

	/// `true` after `start(queue:)` has been called.
	private(set) var didStart = false

	/// `true` after `cancel()` has been called.
	private(set) var didCancel = false

	/// The queue passed to `start(queue:)`, if any.
	private(set) var startQueue: DispatchQueue?

	// MARK: - Initialisation

	/// - Parameter initialPath: The path returned by `currentPath` before the first `simulate`
	///                          call.  Defaults to `MockPath.disconnected` so monitors begin in
	///                          a known-offline state, matching real-device cold-start behaviour.
	init(initialPath: MockPath = .disconnected) {
		self.stubbedCurrentPath = initialPath
	}

	// MARK: - PathMonitorInterface

	func start(queue: DispatchQueue) {
		didStart = true
		startQueue = queue
	}

	func cancel() {
		didCancel = true
	}

	// MARK: - Test control

	/// Simulates the OS delivering a new path update to this monitor.
	///
	/// 1. Updates `stubbedCurrentPath` (so `currentPath` reflects the new state immediately).
	/// 2. Calls `pathUpdateHandler` synchronously on the current thread.
	///
	/// This ordering matches what the real `NWPathMonitor` does: by the time the handler
	/// fires, `currentPath` already reflects the new path.
	///
	/// **Why `MockPath` and not `any PathInterface` or a generic `<P: PathInterface>`?**
	///
	/// Dot-shorthand (`simulate(path: .wifi())`) requires the compiler to resolve the
	/// static member against a *concrete* type.
	///
	/// - With `any PathInterface` (existential): Swift looks up `.wifi()` on the protocol
	///   box and reports "type 'any PathInterface' has no member 'wifi'".
	/// - With `<P: PathInterface>` (generic): Swift infers `P = PathInterface` (the
	///   protocol metatype) rather than `MockPath`, and reports "type 'PathInterface'
	///   has no member 'wifi'" — same root cause, different spelling.
	///
	/// Declaring the parameter as the concrete `MockPath` pins type inference to that
	/// type, so `.wifi()` resolves to `MockPath.wifi()` at every call site.
	func simulate(path: MockPath) {
		stubbedCurrentPath = path   // MockPath coerced to any PathInterface
		pathUpdateHandler?(path)    // MockPath coerced to any PathInterface
	}

	/// Convenience wrapper for the common disconnection scenario.
	/// Equivalent to `simulate(path: .disconnected)`.
	func simulateDisconnect() {
		simulate(path: .disconnected)
	}
}
