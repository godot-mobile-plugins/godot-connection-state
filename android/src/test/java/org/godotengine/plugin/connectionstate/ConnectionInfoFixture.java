//
// © 2025-present https://github.com/cengiz-pz
//

package org.godotengine.plugin.connectionstate.model;

import static org.godotengine.plugin.connectionstate.model.ConnectionInfo.ConnectionType;

/**
 * Static factory methods that produce pre-configured {@link ConnectionInfo}
 * instances for use across unit tests.
 *
 * <p>Each method names its returned state explicitly so test code reads as
 * plain English: {@code ConnectionInfoFixture.wifiActive()} rather than a
 * multi-line builder sequence inside every test.
 */
public final class ConnectionInfoFixture {

	// -------------------------------------------------------------------------
	// Wi-Fi
	// -------------------------------------------------------------------------

	/** Active, unmetered Wi-Fi connection — the most common happy-path state. */
	public static ConnectionInfo wifiActive() {
		ConnectionInfo info = new ConnectionInfo();
		info.setConnectionType(ConnectionType.WIFI);
		info.setIsActive(true);
		info.setIsMetered(false);
		return info;
	}

	/** Inactive (background), unmetered Wi-Fi connection. */
	public static ConnectionInfo wifiInactive() {
		ConnectionInfo info = new ConnectionInfo();
		info.setConnectionType(ConnectionType.WIFI);
		info.setIsActive(false);
		info.setIsMetered(false);
		return info;
	}

	// -------------------------------------------------------------------------
	// Cellular
	// -------------------------------------------------------------------------

	/** Active, metered cellular connection — typical mobile data scenario. */
	public static ConnectionInfo cellularMeteredActive() {
		ConnectionInfo info = new ConnectionInfo();
		info.setConnectionType(ConnectionType.CELLULAR);
		info.setIsActive(true);
		info.setIsMetered(true);
		return info;
	}

	/** Inactive, unmetered cellular connection (e.g. background, unlimited plan). */
	public static ConnectionInfo cellularUnmeteredInactive() {
		ConnectionInfo info = new ConnectionInfo();
		info.setConnectionType(ConnectionType.CELLULAR);
		info.setIsActive(false);
		info.setIsMetered(false);
		return info;
	}

	// -------------------------------------------------------------------------
	// Ethernet
	// -------------------------------------------------------------------------

	/** Active, unmetered Ethernet connection — typical wired device scenario. */
	public static ConnectionInfo ethernetActive() {
		ConnectionInfo info = new ConnectionInfo();
		info.setConnectionType(ConnectionType.ETHERNET);
		info.setIsActive(true);
		info.setIsMetered(false);
		return info;
	}

	// -------------------------------------------------------------------------
	// Bluetooth
	// -------------------------------------------------------------------------

	/** Active, metered Bluetooth tether connection. */
	public static ConnectionInfo bluetoothMeteredActive() {
		ConnectionInfo info = new ConnectionInfo();
		info.setConnectionType(ConnectionType.BLUETOOTH);
		info.setIsActive(true);
		info.setIsMetered(true);
		return info;
	}

	// -------------------------------------------------------------------------
	// VPN
	// -------------------------------------------------------------------------

	/** Active VPN connection, treated as unmetered. */
	public static ConnectionInfo vpnActive() {
		ConnectionInfo info = new ConnectionInfo();
		info.setConnectionType(ConnectionType.VPN);
		info.setIsActive(true);
		info.setIsMetered(false);
		return info;
	}

	// -------------------------------------------------------------------------
	// Unknown / fallback
	// -------------------------------------------------------------------------

	/**
	 * Inactive connection of UNKNOWN type — matches the fallback that
	 * {@code onLost()} emits when the lost network was never cached.
	 */
	public static ConnectionInfo unknownInactive() {
		ConnectionInfo info = new ConnectionInfo();
		info.setConnectionType(ConnectionType.UNKNOWN);
		info.setIsActive(false);
		info.setIsMetered(false);
		return info;
	}

	// -------------------------------------------------------------------------
	// Utility
	// -------------------------------------------------------------------------

	private ConnectionInfoFixture() {
		// static utility class — no instances
	}
}
