//
// © 2025-present https://github.com/cengiz-pz
//

package org.godotengine.plugin.connectionstate.model;

import java.util.List;

import org.godotengine.godot.Dictionary;


public class ConnectionInfo {

	public enum ConnectionType {
		UNKNOWN(0),
		WIFI(1),
		CELLULAR(2),
		ETHERNET(3),
		BLUETOOTH(4),
		VPN(5),
		LOOPBACK(6);

		private final int value;

		private ConnectionType(int value) {
			this.value = value;
		}

		public int getValue() {
			return this.value;
		}
	}

	private static String CONNECTION_TYPE_PROPERTY = "connection_type";
	private static String IS_ACTIVE_PROPERTY = "is_active";
	private static String IS_METERED_PROPERTY = "is_metered";

	private Dictionary data;

	public ConnectionInfo() {
		this.data = new Dictionary();
	}

	public void setConnectionType(ConnectionType type) {
		this.data.put(CONNECTION_TYPE_PROPERTY, type.getValue());
	}

	public void setIsActive(boolean isActive) {
		this.data.put(IS_ACTIVE_PROPERTY, isActive);
	}

	public void setIsMetered(boolean isMetered) {
		this.data.put(IS_METERED_PROPERTY, isMetered);
	}

	public Dictionary getRawData() {
		Dictionary copy = new Dictionary();
		copy.putAll(data);
		return copy;
	}
}
