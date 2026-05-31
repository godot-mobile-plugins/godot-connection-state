//
// © 2025-present https://github.com/cengiz-pz
//
// Run via Gradle: ./gradlew :ios:testiOS
// xcodebuild scheme : connection_state_plugin_tests
// Results bundle   : ios/build/TestResults/testiOS.xcresult
//

@testable import connection_state_plugin
import Network
import XCTest

// MARK: - ConnectionType raw-value constants
// Mirrors the Obj-C NS_ENUM from connection_type.h without a test-target bridging header.
// Values must stay in sync with that enum.
private enum CT {
	static let unknown  = 0
	static let wifi     = 1
	static let cellular = 2
	static let ethernet = 3
	static let vpn      = 5
	static let loopback = 6
}

// MARK: - ConnectionStateTestCase

/// Shared fixture: wires four MockPathMonitor instances into a fresh ConnectionState
/// for every test and accumulates emitted signals in establishedInfos / lostInfos.
class ConnectionStateTestCase: XCTestCase {

	var defaultMonitor: MockPathMonitor!
	var wifiMonitor: MockPathMonitor!
	var cellularMonitor: MockPathMonitor!
	var ethernetMonitor: MockPathMonitor!
	var sut: ConnectionState!

	var establishedInfos: [[String: Any]] = []
	var lostInfos: [[String: Any]] = []

	var typeKey:    String { ConnectionState.connectionTypeKey }
	var activeKey:  String { ConnectionState.isActiveKey }
	var meteredKey: String { ConnectionState.isMeteredKey }

	override func setUp() {
		super.setUp()
		defaultMonitor  = MockPathMonitor()
		wifiMonitor     = MockPathMonitor()
		cellularMonitor = MockPathMonitor()
		ethernetMonitor = MockPathMonitor()
		buildSUT()
	}

	override func tearDown() { sut = nil; super.tearDown() }

	func buildSUT() {
		establishedInfos = []
		lostInfos = []
		sut = ConnectionState(
			defaultMonitor: defaultMonitor,
			wifiMonitor: wifiMonitor,
			cellularMonitor: cellularMonitor,
			ethernetMonitor: ethernetMonitor
		)
		sut.onConnectionEstablished = { [weak self] info in self?.establishedInfos.append(info) }
		sut.onConnectionLost        = { [weak self] info in self?.lostInfos.append(info) }
	}

	@discardableResult
	func connectDefault(via path: MockPath = .wifi()) -> MockPath {
		defaultMonitor.simulate(path: path)
		return path
	}
}

// MARK: - Suite 1 · Monitor Lifecycle

final class ConnectionStateLifecycleTests: ConnectionStateTestCase {

	func test_allMonitors_areStarted_duringInit() {
		XCTAssertTrue(defaultMonitor.didStart,  "default monitor must be started")
		XCTAssertTrue(wifiMonitor.didStart,     "wifi monitor must be started")
		XCTAssertTrue(cellularMonitor.didStart, "cellular monitor must be started")
		XCTAssertTrue(ethernetMonitor.didStart, "ethernet monitor must be started")
	}

	func test_allMonitors_haveHandlersAssigned_duringInit() {
		XCTAssertNotNil(defaultMonitor.pathUpdateHandler,  "default handler must be set")
		XCTAssertNotNil(wifiMonitor.pathUpdateHandler,     "wifi handler must be set")
		XCTAssertNotNil(cellularMonitor.pathUpdateHandler, "cellular handler must be set")
		XCTAssertNotNil(ethernetMonitor.pathUpdateHandler, "ethernet handler must be set")
	}

	// All monitors must share the same serial queue to serialise state mutations.
	func test_allMonitors_startedOnSameQueue() {
		XCTAssertNotNil(defaultMonitor.startQueue)
		XCTAssertEqual(defaultMonitor.startQueue?.label,  wifiMonitor.startQueue?.label)
		XCTAssertEqual(wifiMonitor.startQueue?.label,     cellularMonitor.startQueue?.label)
		XCTAssertEqual(cellularMonitor.startQueue?.label, ethernetMonitor.startQueue?.label)
	}

	func test_allMonitors_areCancelled_onDeinit() {
		let dm = defaultMonitor!
		let wm = wifiMonitor!
		let cm = cellularMonitor!
		let em = ethernetMonitor!
		sut = nil
		XCTAssertTrue(dm.didCancel, "default monitor must be cancelled on deinit")
		XCTAssertTrue(wm.didCancel, "wifi monitor must be cancelled on deinit")
		XCTAssertTrue(cm.didCancel, "cellular monitor must be cancelled on deinit")
		XCTAssertTrue(em.didCancel, "ethernet monitor must be cancelled on deinit")
	}
}

// MARK: - Suite 2 · getCurrentState()

final class ConnectionStateQueryTests: ConnectionStateTestCase {

	func test_getCurrentState_isEmpty_whenNoMonitorsAreSatisfied() {
		XCTAssertTrue(sut.getCurrentState().isEmpty)
	}

	func test_getCurrentState_returnsOneWifiEntry_whenOnlyWifiSatisfied() {
		wifiMonitor.stubbedCurrentPath    = MockPath.wifi()
		defaultMonitor.stubbedCurrentPath = MockPath.wifi()
		let state = sut.getCurrentState()
		XCTAssertEqual(state.count, 1)
		XCTAssertEqual(state[0][typeKey] as? Int, CT.wifi)
	}

	func test_getCurrentState_returnsOneCellularEntry_whenOnlyCellularSatisfied() {
		cellularMonitor.stubbedCurrentPath = MockPath.cellular()
		defaultMonitor.stubbedCurrentPath  = MockPath.cellular()
		let state = sut.getCurrentState()
		XCTAssertEqual(state.count, 1)
		XCTAssertEqual(state[0][typeKey] as? Int, CT.cellular)
	}

	func test_getCurrentState_returnsOneEthernetEntry_whenOnlyEthernetSatisfied() {
		ethernetMonitor.stubbedCurrentPath = MockPath.ethernet()
		defaultMonitor.stubbedCurrentPath  = MockPath.ethernet()
		let state = sut.getCurrentState()
		XCTAssertEqual(state.count, 1)
		XCTAssertEqual(state[0][typeKey] as? Int, CT.ethernet)
	}

	func test_getCurrentState_returnsTwoEntries_whenWifiAndCellularSatisfied() {
		wifiMonitor.stubbedCurrentPath     = MockPath.wifi()
		cellularMonitor.stubbedCurrentPath = MockPath.cellular()
		defaultMonitor.stubbedCurrentPath  = MockPath.wifi()
		XCTAssertEqual(sut.getCurrentState().count, 2)
	}

	// When only the default monitor is satisfied, getCurrentState() returns a VPN entry so
	// that tunnelled connections are surfaced to the caller via the .other interface fallback.
	func test_getCurrentState_returnsVpnEntry_whenOnlyDefaultSatisfied() {
		defaultMonitor.stubbedCurrentPath = MockPath.vpn()
		let state = sut.getCurrentState()
		XCTAssertEqual(state.count, 1)
		XCTAssertEqual(state[0][typeKey]   as? Int,  CT.vpn)
		XCTAssertEqual(state[0][activeKey] as? Bool, true)
	}

	func test_getCurrentState_marksWifiActive_whenDefaultUsesWifi() {
		wifiMonitor.stubbedCurrentPath     = MockPath.wifi()
		cellularMonitor.stubbedCurrentPath = MockPath.cellular()
		defaultMonitor.stubbedCurrentPath  = MockPath.wifi()
		let state = sut.getCurrentState()
		let wifi     = state.first { $0[typeKey] as? Int == CT.wifi }
		let cellular = state.first { $0[typeKey] as? Int == CT.cellular }
		XCTAssertEqual(wifi?[activeKey]     as? Bool, true,  "WiFi must be active")
		XCTAssertEqual(cellular?[activeKey] as? Bool, false, "Cellular must be secondary")
	}

	func test_getCurrentState_marksCellularActive_whenDefaultUsesCellular() {
		wifiMonitor.stubbedCurrentPath     = MockPath.wifi()
		cellularMonitor.stubbedCurrentPath = MockPath.cellular()
		defaultMonitor.stubbedCurrentPath  = MockPath.cellular()
		let state = sut.getCurrentState()
		let wifi     = state.first { $0[typeKey] as? Int == CT.wifi }
		let cellular = state.first { $0[typeKey] as? Int == CT.cellular }
		XCTAssertEqual(cellular?[activeKey] as? Bool, true,  "Cellular must be active")
		XCTAssertEqual(wifi?[activeKey]     as? Bool, false, "WiFi must be secondary")
	}

	func test_getCurrentState_isMetered_true_whenPathIsExpensive() {
		let path = MockPath.wifi(metered: true)
		wifiMonitor.stubbedCurrentPath    = path
		defaultMonitor.stubbedCurrentPath = path
		XCTAssertEqual(sut.getCurrentState().first?[meteredKey] as? Bool, true)
	}

	// getCurrentState() must always emit entries in canonical order: WiFi → Cellular → Ethernet.
	func test_getCurrentState_entryOrderIsWifiThenCellularThenEthernet() {
		wifiMonitor.stubbedCurrentPath     = MockPath.wifi()
		cellularMonitor.stubbedCurrentPath = MockPath.cellular()
		ethernetMonitor.stubbedCurrentPath = MockPath.ethernet()
		defaultMonitor.stubbedCurrentPath  = MockPath.wifi()
		let types = sut.getCurrentState().compactMap { $0[typeKey] as? Int }
		XCTAssertEqual(types, [CT.wifi, CT.cellular, CT.ethernet])
	}
}

// MARK: - Suite 3 · onConnectionEstablished signal

final class ConnectionStateEstablishedTests: ConnectionStateTestCase {

	func test_established_firedOnce_whenDefaultFirstBecomeSatisfied() {
		connectDefault()
		XCTAssertEqual(establishedInfos.count, 1)
	}

	func test_established_notFiredAgain_whenAlreadyConnected() {
		connectDefault()
		connectDefault()
		XCTAssertEqual(establishedInfos.count, 1)
	}

	func test_established_firedAgain_afterFullReconnect() {
		connectDefault()
		defaultMonitor.simulateDisconnect()
		connectDefault()
		XCTAssertEqual(establishedInfos.count, 2)
	}

	func test_established_notFired_whenPathIsUnsatisfied() {
		defaultMonitor.simulateDisconnect()
		XCTAssertTrue(establishedInfos.isEmpty)
	}

	func test_established_info_type_wifi() {
		connectDefault(via: .wifi())
		XCTAssertEqual(establishedInfos[0][typeKey] as? Int, CT.wifi)
	}

	func test_established_info_type_cellular() {
		connectDefault(via: .cellular())
		XCTAssertEqual(establishedInfos[0][typeKey] as? Int, CT.cellular)
	}

	func test_established_info_type_ethernet() {
		connectDefault(via: .ethernet())
		XCTAssertEqual(establishedInfos[0][typeKey] as? Int, CT.ethernet)
	}

	func test_established_info_type_loopback() {
		connectDefault(via: .loopback())
		XCTAssertEqual(establishedInfos[0][typeKey] as? Int, CT.loopback)
	}

	func test_established_info_type_vpn_forOtherInterface() {
		connectDefault(via: .vpn())
		XCTAssertEqual(establishedInfos[0][typeKey] as? Int, CT.vpn)
	}

	func test_established_info_type_unknown_whenNoInterfaceMatches() {
		connectDefault(via: .unknown())
		XCTAssertEqual(establishedInfos[0][typeKey] as? Int, CT.unknown)
	}

	// The default monitor always represents the primary (active) path.
	func test_established_info_isActive_isAlwaysTrue() {
		connectDefault()
		XCTAssertEqual(establishedInfos[0][activeKey] as? Bool, true)
	}

	func test_established_info_isMetered_true_whenPathIsExpensive() {
		connectDefault(via: .cellular(metered: true))
		XCTAssertEqual(establishedInfos[0][meteredKey] as? Bool, true)
	}

	// Reconnect must produce a fresh info dict, not a stale cached one.
	func test_established_info_reflectsNewPathType_afterTypeChangeOnReconnect() {
		connectDefault(via: .wifi())
		defaultMonitor.simulateDisconnect()
		connectDefault(via: .cellular())
		XCTAssertEqual(establishedInfos.count, 2)
		XCTAssertEqual(establishedInfos[0][typeKey] as? Int, CT.wifi,     "first connect: WiFi")
		XCTAssertEqual(establishedInfos[1][typeKey] as? Int, CT.cellular, "second connect: Cellular")
	}
}

// MARK: - Suite 4 · onConnectionLost signal

final class ConnectionStateLostTests: ConnectionStateTestCase {

	func test_lost_firedOnce_whenDefaultBecomesUnsatisfied() {
		connectDefault()
		defaultMonitor.simulateDisconnect()
		XCTAssertEqual(lostInfos.count, 1)
	}

	func test_lost_notFired_whenNeverConnected() {
		defaultMonitor.simulateDisconnect()
		XCTAssertTrue(lostInfos.isEmpty)
	}

	func test_lost_notFiredAgain_whileStillDisconnected() {
		connectDefault()
		defaultMonitor.simulateDisconnect()
		defaultMonitor.simulateDisconnect()
		XCTAssertEqual(lostInfos.count, 1)
	}

	func test_lost_firedTwice_afterTwoConnectDisconnectCycles() {
		connectDefault()
		defaultMonitor.simulateDisconnect()
		connectDefault()
		defaultMonitor.simulateDisconnect()
		XCTAssertEqual(lostInfos.count, 2)
	}

	func test_lost_info_isActive_isFalse() {
		connectDefault()
		defaultMonitor.simulateDisconnect()
		XCTAssertEqual(lostInfos[0][activeKey] as? Bool, false)
	}

	// When the default path goes down, ConnectionState uses the cached info dict so the
	// caller knows WHAT connection was lost, not just that something was.
	func test_lost_info_preservesWifiType_fromCachedEstablishedInfo() {
		connectDefault(via: .wifi())
		defaultMonitor.simulateDisconnect()
		XCTAssertEqual(lostInfos[0][typeKey] as? Int, CT.wifi)
	}

	// Second disconnect must carry the NEW connection's type, not the stale cached one.
	func test_lost_info_reflectsNewTypeAfterTypeChangeOnReconnect() {
		connectDefault(via: .wifi())
		defaultMonitor.simulateDisconnect()
		connectDefault(via: .cellular())
		defaultMonitor.simulateDisconnect()
		XCTAssertEqual(lostInfos[0][typeKey] as? Int, CT.wifi,     "first loss: WiFi")
		XCTAssertEqual(lostInfos[1][typeKey] as? Int, CT.cellular, "second loss: Cellular")
	}
}

// MARK: - Suite 5 · Specific-interface updates (handleSpecificUpdate)

final class ConnectionStateSpecificInterfaceTests: ConnectionStateTestCase {

	// Connecting a non-active interface must NOT fire onConnectionEstablished —
	// that signal is the exclusive domain of the default monitor.
	func test_specificConnect_doesNotFireEstablished_forSecondaryWifi() {
		defaultMonitor.stubbedCurrentPath  = MockPath.cellular()
		cellularMonitor.stubbedCurrentPath = MockPath.cellular()
		wifiMonitor.simulate(path: .wifi())
		XCTAssertTrue(establishedInfos.isEmpty,
			"handleSpecificUpdate must never fire onConnectionEstablished")
	}

	func test_specificConnect_doesNotFireLost_whenInterfaceComeUp() {
		defaultMonitor.stubbedCurrentPath = MockPath.cellular()
		wifiMonitor.simulate(path: .wifi())
		XCTAssertTrue(lostInfos.isEmpty)
	}

	func test_specificConnect_marksWifi_notActive_whenCellularIsDefault() {
		defaultMonitor.stubbedCurrentPath = MockPath.cellular()
		wifiMonitor.simulate(path: .wifi())
		let wifiEntry = sut.getCurrentState().first { $0[typeKey] as? Int == CT.wifi }
		XCTAssertEqual(wifiEntry?[activeKey] as? Bool, false)
	}

	func test_specificLost_firesOnce_forNonActiveWifi() {
		defaultMonitor.stubbedCurrentPath  = MockPath.cellular()
		cellularMonitor.stubbedCurrentPath = MockPath.cellular()
		wifiMonitor.simulate(path: .wifi())          // isActive = false (default is cellular)
		wifiMonitor.simulate(path: .disconnected)    // drop non-active WiFi
		XCTAssertEqual(lostInfos.count, 1)
		XCTAssertEqual(lostInfos[0][typeKey]   as? Int,  CT.wifi)
		XCTAssertEqual(lostInfos[0][activeKey] as? Bool, false)
	}

	func test_specificLost_firesOnce_forNonActiveCellular() {
		defaultMonitor.stubbedCurrentPath = MockPath.wifi()
		wifiMonitor.stubbedCurrentPath    = MockPath.wifi()
		cellularMonitor.simulate(path: .cellular())  // isActive = false
		cellularMonitor.simulate(path: .disconnected)
		XCTAssertEqual(lostInfos.count, 1)
		XCTAssertEqual(lostInfos[0][typeKey] as? Int, CT.cellular)
	}

	func test_specificLost_info_preservesCachedType() {
		defaultMonitor.stubbedCurrentPath = MockPath.cellular()
		wifiMonitor.simulate(path: .wifi())
		wifiMonitor.simulate(path: .disconnected)
		XCTAssertEqual(lostInfos.first?[typeKey] as? Int, CT.wifi,
			"lost info must come from the cached lastWifiInfo, not an empty dict")
	}

	func test_specificLost_fired_eachCycle_forRepeatedConnectDisconnect() {
		defaultMonitor.stubbedCurrentPath = MockPath.cellular()
		wifiMonitor.simulate(path: .wifi())
		wifiMonitor.simulate(path: .disconnected)
		wifiMonitor.simulate(path: .wifi())
		wifiMonitor.simulate(path: .disconnected)
		XCTAssertEqual(lostInfos.count, 2)
	}

	// When the primary interface goes down, two lost events fire in sequence:
	//   1. Default monitor → handleDefaultUpdate → emits lost #1 →
	//      updateSpecificInterfaceStates sets WiFi isActive = false.
	//   2. WiFi monitor → handleSpecificUpdate → wasActive = false (cleared above) → emits lost #2.
	// This documents the synchronous test ordering; in production ordering is non-deterministic.
	func test_activePrimaryDown_emitsTwoLostEvents_defaultThenSpecific() {
		defaultMonitor.stubbedCurrentPath = MockPath.wifi()
		wifiMonitor.stubbedCurrentPath    = MockPath.wifi()
		wifiMonitor.simulate(path: .wifi())
		defaultMonitor.simulate(path: .wifi())   // fires established; updateSpecific → WiFi isActive=true
		let establishedBefore = establishedInfos.count

		defaultMonitor.simulate(path: .disconnected)  // lost #1; updateSpecific → WiFi isActive=false
		wifiMonitor.simulate(path: .disconnected)     // wasActive=false → lost #2

		XCTAssertEqual(establishedInfos.count, establishedBefore, "no extra established events")
		XCTAssertEqual(lostInfos.count, 2,
			"one lost from the default monitor, one from the WiFi monitor " +
			"(isActive was cleared synchronously by updateSpecificInterfaceStates)")
		XCTAssertEqual(lostInfos[0][typeKey] as? Int, CT.wifi, "lost #1: type = wifi")
		XCTAssertEqual(lostInfos[1][typeKey] as? Int, CT.wifi, "lost #2: type = wifi")
	}
}

// MARK: - Suite 6 · updateSpecificInterfaceStates (triggered by default monitor)

final class ConnectionStateUpdateSpecificTests: ConnectionStateTestCase {

	func test_updateSpecific_wifiMarkedActive_whenDefaultConnectsViaWifi() {
		wifiMonitor.stubbedCurrentPath    = MockPath.wifi()
		defaultMonitor.stubbedCurrentPath = MockPath.wifi()
		connectDefault(via: .wifi())
		let wifiEntry = sut.getCurrentState().first { $0[typeKey] as? Int == CT.wifi }
		XCTAssertEqual(wifiEntry?[activeKey] as? Bool, true)
	}

	func test_updateSpecific_cellularMarkedSecondary_whenDefaultConnectsViaWifi() {
		wifiMonitor.stubbedCurrentPath     = MockPath.wifi()
		cellularMonitor.stubbedCurrentPath = MockPath.cellular()
		defaultMonitor.stubbedCurrentPath  = MockPath.wifi()
		connectDefault(via: .wifi())
		let cellular = sut.getCurrentState().first { $0[typeKey] as? Int == CT.cellular }
		XCTAssertEqual(cellular?[activeKey] as? Bool, false)
	}

	func test_updateSpecific_activeChanges_whenDefaultSwitchesFromCellularToWifi() {
		wifiMonitor.stubbedCurrentPath     = MockPath.wifi()
		cellularMonitor.stubbedCurrentPath = MockPath.cellular()
		defaultMonitor.stubbedCurrentPath  = MockPath.cellular()
		connectDefault(via: .cellular())
		defaultMonitor.stubbedCurrentPath = MockPath.wifi()
		connectDefault(via: .wifi())
		let state    = sut.getCurrentState()
		let wifi     = state.first { $0[typeKey] as? Int == CT.wifi }
		let cellular = state.first { $0[typeKey] as? Int == CT.cellular }
		XCTAssertEqual(wifi?[activeKey]     as? Bool, true,  "WiFi must now be active")
		XCTAssertEqual(cellular?[activeKey] as? Bool, false, "Cellular must now be secondary")
	}

	// After the default path goes down, the previously-active interface must be marked
	// isActive = false — not removed, since it is still technically connected.
	func test_updateSpecific_wifiMarkedNotActive_whenDefaultPathIsLost() {
		wifiMonitor.stubbedCurrentPath    = MockPath.wifi()
		defaultMonitor.stubbedCurrentPath = MockPath.wifi()
		connectDefault(via: .wifi())
		defaultMonitor.simulate(path: .disconnected)
		let wifiEntry = sut.getCurrentState().first { $0[typeKey] as? Int == CT.wifi }
		XCTAssertEqual(wifiEntry?[activeKey] as? Bool, false)
		XCTAssertEqual(lostInfos.count, 1, "exactly one lost event must fire")
	}

	func test_updateSpecific_wifiStillAppearsInState_afterDefaultLost() {
		wifiMonitor.stubbedCurrentPath    = MockPath.wifi()
		defaultMonitor.stubbedCurrentPath = MockPath.wifi()
		connectDefault(via: .wifi())
		defaultMonitor.simulate(path: .disconnected)
		XCTAssertFalse(sut.getCurrentState().isEmpty,
			"WiFi must still be listed even when the default monitor is unsatisfied")
	}
}

// MARK: - Suite 7 · Dictionary-key contract
// The Obj-C bridge reads these exact strings; they must never change silently.

final class ConnectionStateDictionaryKeyTests: ConnectionStateTestCase {

	func test_connectionTypeKey_equals_connection_type() {
		XCTAssertEqual(ConnectionState.connectionTypeKey, "connection_type")
	}

	func test_isActiveKey_equals_is_active() {
		XCTAssertEqual(ConnectionState.isActiveKey, "is_active")
	}

	func test_isMeteredKey_equals_is_metered() {
		XCTAssertEqual(ConnectionState.isMeteredKey, "is_metered")
	}

	// The Obj-C bridge reads connection_type as NSInteger; ensure it round-trips as Int.
	func test_dictionaryValue_forConnectionType_isInt() {
		connectDefault(via: .wifi())
		XCTAssertTrue(establishedInfos.first?[typeKey] is Int,
			"connection_type must be an Int (ConnectionType.rawValue)")
	}

	func test_dictionaryValue_forIsActive_isBool() {
		connectDefault()
		XCTAssertTrue(establishedInfos.first?[activeKey] is Bool)
	}

	func test_dictionaryValue_forIsMetered_isBool() {
		connectDefault()
		XCTAssertTrue(establishedInfos.first?[meteredKey] is Bool)
	}
}

// MARK: - Suite 8 · Nil-callback safety

final class ConnectionStateNilCallbackTests: ConnectionStateTestCase {

	// The Obj-C bridge may not have assigned callbacks yet when the first path update fires.
	func test_nilCallbacks_doNotCrash_onEstablished() {
		sut.onConnectionEstablished = nil
		sut.onConnectionLost = nil
		XCTAssertNoThrow(connectDefault())
	}

	func test_nilCallbacks_doNotCrash_onLost() {
		connectDefault()
		sut.onConnectionEstablished = nil
		sut.onConnectionLost = nil
		XCTAssertNoThrow(defaultMonitor.simulateDisconnect())
	}

	// Reassigning a callback mid-session must not leak events to the old closure.
	func test_replacingCallback_midSession_receivesSubsequentEvents() {
		connectDefault()
		var laterEstablished: [[String: Any]] = []
		sut.onConnectionEstablished = { laterEstablished.append($0) }
		defaultMonitor.simulateDisconnect()
		connectDefault()   // fires the NEW callback only
		XCTAssertEqual(laterEstablished.count, 1,
			"new callback must receive exactly the events that occur after assignment")
		XCTAssertEqual(establishedInfos.count, 1,
			"old callback must not receive events after it is replaced")
	}
}
