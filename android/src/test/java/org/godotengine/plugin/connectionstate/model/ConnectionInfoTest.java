//
// © 2025-present https://github.com/cengiz-pz
//

package org.godotengine.plugin.connectionstate.model;

import org.godotengine.godot.Dictionary;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.util.Arrays;
import java.util.Set;
import java.util.stream.Collectors;

import static org.godotengine.plugin.connectionstate.model.ConnectionInfo.ConnectionType;
import static org.junit.jupiter.api.Assertions.assertAll;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNotSame;

/**
 * Unit tests for {@link ConnectionInfo}.
 *
 * <p>{@code ConnectionInfo} is pure Java (its {@link Dictionary} backing store
 * extends {@link java.util.HashMap}), so no Android SDK stubs or mocking
 * frameworks are needed here. All tests run as plain JUnit 5 tests.
 *
 * <p>Coverage targets:
 * <ul>
 *   <li>{@link ConnectionType} — numeric contract for every enum constant</li>
 *   <li>{@code setConnectionType()} — correct int stored, last write wins</li>
 *   <li>{@code setIsActive()} — boolean stored, toggle semantics</li>
 *   <li>{@code setIsMetered()} — boolean stored, toggle semantics</li>
 *   <li>{@code getRawData()} — non-null, defensive copy, mutation isolation,
 *       correct values after all setters</li>
 *   <li>Fixture sanity — each {@link ConnectionInfoFixture} method produces the
 *       exact dictionary values its name implies</li>
 * </ul>
 */
@DisplayName("ConnectionInfo")
class ConnectionInfoTest {

	/** Fresh instance created before every test to avoid state leakage. */
	private ConnectionInfo sut;

	@BeforeEach
	void setUp() {
		sut = new ConnectionInfo();
	}

	// =========================================================================
	// ConnectionType enum
	// =========================================================================

	@Nested
	@DisplayName("ConnectionType enum")
	class ConnectionTypeEnumTest {

		@Test
		@DisplayName("has exactly 7 members")
		void hasSevenMembers() {
			assertEquals(7, ConnectionType.values().length);
		}

		@Test
		@DisplayName("UNKNOWN maps to integer 0")
		void unknownIsZero() {
			assertEquals(0, ConnectionType.UNKNOWN.getValue());
		}

		@Test
		@DisplayName("WIFI maps to integer 1")
		void wifiIsOne() {
			assertEquals(1, ConnectionType.WIFI.getValue());
		}

		@Test
		@DisplayName("CELLULAR maps to integer 2")
		void cellularIsTwo() {
			assertEquals(2, ConnectionType.CELLULAR.getValue());
		}

		@Test
		@DisplayName("ETHERNET maps to integer 3")
		void ethernetIsThree() {
			assertEquals(3, ConnectionType.ETHERNET.getValue());
		}

		@Test
		@DisplayName("BLUETOOTH maps to integer 4")
		void bluetoothIsFour() {
			assertEquals(4, ConnectionType.BLUETOOTH.getValue());
		}

		@Test
		@DisplayName("VPN maps to integer 5")
		void vpnIsFive() {
			assertEquals(5, ConnectionType.VPN.getValue());
		}

		@Test
		@DisplayName("LOOPBACK maps to integer 6")
		void loopbackIsSix() {
			assertEquals(6, ConnectionType.LOOPBACK.getValue());
		}

		@Test
		@DisplayName("all integer values are unique — no two constants share a code")
		void allIntegerValuesAreUnique() {
			Set<Integer> distinct = Arrays.stream(ConnectionType.values())
					.map(ConnectionType::getValue)
					.collect(Collectors.toSet());

			assertEquals(
					ConnectionType.values().length,
					distinct.size(),
					"each ConnectionType must have a distinct integer value");
		}
	}

	// =========================================================================
	// setConnectionType()
	// =========================================================================

	@Nested
	@DisplayName("setConnectionType()")
	class SetConnectionTypeTest {

		@Test
		@DisplayName("stores UNKNOWN (0) in the backing dictionary")
		void storesUnknown() {
			sut.setConnectionType(ConnectionType.UNKNOWN);
			assertEquals(0, sut.getRawData().get("connection_type"));
		}

		@Test
		@DisplayName("stores WIFI (1) in the backing dictionary")
		void storesWifi() {
			sut.setConnectionType(ConnectionType.WIFI);
			assertEquals(1, sut.getRawData().get("connection_type"));
		}

		@Test
		@DisplayName("stores CELLULAR (2) in the backing dictionary")
		void storesCellular() {
			sut.setConnectionType(ConnectionType.CELLULAR);
			assertEquals(2, sut.getRawData().get("connection_type"));
		}

		@Test
		@DisplayName("stores ETHERNET (3) in the backing dictionary")
		void storesEthernet() {
			sut.setConnectionType(ConnectionType.ETHERNET);
			assertEquals(3, sut.getRawData().get("connection_type"));
		}

		@Test
		@DisplayName("stores BLUETOOTH (4) in the backing dictionary")
		void storesBluetooth() {
			sut.setConnectionType(ConnectionType.BLUETOOTH);
			assertEquals(4, sut.getRawData().get("connection_type"));
		}

		@Test
		@DisplayName("stores VPN (5) in the backing dictionary")
		void storesVpn() {
			sut.setConnectionType(ConnectionType.VPN);
			assertEquals(5, sut.getRawData().get("connection_type"));
		}

		@Test
		@DisplayName("stores LOOPBACK (6) in the backing dictionary")
		void storesLoopback() {
			sut.setConnectionType(ConnectionType.LOOPBACK);
			assertEquals(6, sut.getRawData().get("connection_type"));
		}

		@Test
		@DisplayName("last call wins — subsequent type overwrites the previous one")
		void lastCallWins() {
			sut.setConnectionType(ConnectionType.WIFI);      // 1
			sut.setConnectionType(ConnectionType.CELLULAR);  // 2 — must win
			assertEquals(2, sut.getRawData().get("connection_type"));
		}
	}

	// =========================================================================
	// setIsActive()
	// =========================================================================

	@Nested
	@DisplayName("setIsActive()")
	class SetIsActiveTest {

		@Test
		@DisplayName("stores true in the backing dictionary")
		void storesTrue() {
			sut.setIsActive(true);
			assertEquals(true, sut.getRawData().get("is_active"));
		}

		@Test
		@DisplayName("stores false in the backing dictionary")
		void storesFalse() {
			sut.setIsActive(false);
			assertEquals(false, sut.getRawData().get("is_active"));
		}

		@Test
		@DisplayName("toggling true → false persists the new value")
		void trueToFalseIsPersistedCorrectly() {
			sut.setIsActive(true);
			sut.setIsActive(false);
			assertEquals(false, sut.getRawData().get("is_active"));
		}

		@Test
		@DisplayName("toggling false → true persists the new value")
		void falseToTrueIsPersistedCorrectly() {
			sut.setIsActive(false);
			sut.setIsActive(true);
			assertEquals(true, sut.getRawData().get("is_active"));
		}
	}

	// =========================================================================
	// setIsMetered()
	// =========================================================================

	@Nested
	@DisplayName("setIsMetered()")
	class SetIsMeteredTest {

		@Test
		@DisplayName("stores true in the backing dictionary")
		void storesTrue() {
			sut.setIsMetered(true);
			assertEquals(true, sut.getRawData().get("is_metered"));
		}

		@Test
		@DisplayName("stores false in the backing dictionary")
		void storesFalse() {
			sut.setIsMetered(false);
			assertEquals(false, sut.getRawData().get("is_metered"));
		}

		@Test
		@DisplayName("toggling metered → unmetered persists the new value")
		void meteredToUnmeteredIsPersistedCorrectly() {
			sut.setIsMetered(true);
			sut.setIsMetered(false);
			assertEquals(false, sut.getRawData().get("is_metered"));
		}

		@Test
		@DisplayName("toggling unmetered → metered persists the new value")
		void unmeteredToMeteredIsPersistedCorrectly() {
			sut.setIsMetered(false);
			sut.setIsMetered(true);
			assertEquals(true, sut.getRawData().get("is_metered"));
		}
	}

	// =========================================================================
	// getRawData()
	// =========================================================================

	@Nested
	@DisplayName("getRawData()")
	class GetRawDataTest {

		@Test
		@DisplayName("never returns null")
		void neverReturnsNull() {
			assertNotNull(sut.getRawData());
		}

		@Test
		@DisplayName("each call returns a different Dictionary instance (defensive copy)")
		void eachCallReturnsANewInstance() {
			Dictionary first = sut.getRawData();
			Dictionary second = sut.getRawData();
			assertNotSame(first, second,
					"getRawData() must return a fresh copy on each call");
		}

		@Test
		@DisplayName("mutating the returned Dictionary does NOT affect the internal state")
		void mutatingReturnedCopyLeavesInternalStateIntact() {
			sut.setConnectionType(ConnectionType.WIFI); // stored as 1

			Dictionary copy = sut.getRawData();
			copy.put("connection_type", 999);           // tamper with the copy

			assertEquals(1, sut.getRawData().get("connection_type"),
					"the original internal data must not be reachable via the returned copy");
		}

		@Test
		@DisplayName("contains all three properties with correct values after full setup")
		void containsAllThreePropertiesAfterFullSetup() {
			sut.setConnectionType(ConnectionType.ETHERNET);
			sut.setIsActive(true);
			sut.setIsMetered(false);

			Dictionary data = sut.getRawData();
			assertAll(
					() -> assertEquals(3, data.get("connection_type"), "connection_type"),
					() -> assertEquals(true, data.get("is_active"), "is_active"),
					() -> assertEquals(false, data.get("is_metered"), "is_metered")
			);
		}
	}

	// =========================================================================
	// Fixture sanity checks
	// =========================================================================

	@Nested
	@DisplayName("ConnectionInfoFixture sanity checks")
	class FixtureSanityTest {

		@Test
		@DisplayName("wifiActive() → type=1, active=true, metered=false")
		void wifiActiveFixtureIsCorrect() {
			Dictionary data = ConnectionInfoFixture.wifiActive().getRawData();
			assertAll(
					() -> assertEquals(1, data.get("connection_type")),
					() -> assertEquals(true, data.get("is_active")),
					() -> assertEquals(false, data.get("is_metered"))
			);
		}

		@Test
		@DisplayName("wifiInactive() → type=1, active=false, metered=false")
		void wifiInactiveFixtureIsCorrect() {
			Dictionary data = ConnectionInfoFixture.wifiInactive().getRawData();
			assertAll(
					() -> assertEquals(1, data.get("connection_type")),
					() -> assertEquals(false, data.get("is_active")),
					() -> assertEquals(false, data.get("is_metered"))
			);
		}

		@Test
		@DisplayName("cellularMeteredActive() → type=2, active=true, metered=true")
		void cellularMeteredActiveFixtureIsCorrect() {
			Dictionary data = ConnectionInfoFixture.cellularMeteredActive().getRawData();
			assertAll(
					() -> assertEquals(2, data.get("connection_type")),
					() -> assertEquals(true, data.get("is_active")),
					() -> assertEquals(true, data.get("is_metered"))
			);
		}

		@Test
		@DisplayName("cellularUnmeteredInactive() → type=2, active=false, metered=false")
		void cellularUnmeteredInactiveFixtureIsCorrect() {
			Dictionary data = ConnectionInfoFixture.cellularUnmeteredInactive().getRawData();
			assertAll(
					() -> assertEquals(2, data.get("connection_type")),
					() -> assertEquals(false, data.get("is_active")),
					() -> assertEquals(false, data.get("is_metered"))
			);
		}

		@Test
		@DisplayName("ethernetActive() → type=3, active=true, metered=false")
		void ethernetActiveFixtureIsCorrect() {
			Dictionary data = ConnectionInfoFixture.ethernetActive().getRawData();
			assertAll(
					() -> assertEquals(3, data.get("connection_type")),
					() -> assertEquals(true, data.get("is_active")),
					() -> assertEquals(false, data.get("is_metered"))
			);
		}

		@Test
		@DisplayName("bluetoothMeteredActive() → type=4, active=true, metered=true")
		void bluetoothMeteredActiveFixtureIsCorrect() {
			Dictionary data = ConnectionInfoFixture.bluetoothMeteredActive().getRawData();
			assertAll(
					() -> assertEquals(4, data.get("connection_type")),
					() -> assertEquals(true, data.get("is_active")),
					() -> assertEquals(true, data.get("is_metered"))
			);
		}

		@Test
		@DisplayName("vpnActive() → type=5, active=true, metered=false")
		void vpnActiveFixtureIsCorrect() {
			Dictionary data = ConnectionInfoFixture.vpnActive().getRawData();
			assertAll(
					() -> assertEquals(5, data.get("connection_type")),
					() -> assertEquals(true, data.get("is_active")),
					() -> assertEquals(false, data.get("is_metered"))
			);
		}

		@Test
		@DisplayName("unknownInactive() → type=0, active=false, metered=false")
		void unknownInactiveFixtureIsCorrect() {
			Dictionary data = ConnectionInfoFixture.unknownInactive().getRawData();
			assertAll(
					() -> assertEquals(0, data.get("connection_type")),
					() -> assertEquals(false, data.get("is_active")),
					() -> assertEquals(false, data.get("is_metered"))
			);
		}
	}
}
