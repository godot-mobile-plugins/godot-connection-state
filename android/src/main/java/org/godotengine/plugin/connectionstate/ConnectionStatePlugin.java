//
// © 2025-present https://github.com/cengiz-pz
//

package org.godotengine.plugin.connectionstate;

import android.app.Activity;
import android.content.Context;
import android.net.ConnectivityManager;
import android.net.LinkProperties;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.NetworkRequest;
import android.view.View;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import org.godotengine.godot.Godot;
import org.godotengine.godot.Dictionary;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import org.godotengine.plugin.connectionstate.model.ConnectionInfo;
import static org.godotengine.plugin.connectionstate.model.ConnectionInfo.ConnectionType;


public class ConnectionStatePlugin extends GodotPlugin {
	public static final String CLASS_NAME = ConnectionStatePlugin.class.getSimpleName();
	static final String LOG_TAG = "godot::" + CLASS_NAME;


	static final String CONNECTION_ESTABLISHED_SIGNAL = "connection_established";
	static final String CONNECTION_LOST_SIGNAL = "connection_lost";

	private ConnectivityManager connectivityManager;
	private ConnectivityManager.NetworkCallback networkCallback;

	// Thread-safe cache to store active networks
	// Key: Network object (unique ID), Value: ConnectionInfo
	private final Map<Network, ConnectionInfo> activeNetworkCache = new ConcurrentHashMap<>();

	public ConnectionStatePlugin(Godot godot) {
		super(godot);
	}

	@Override
	public String getPluginName() {
		return CLASS_NAME;
	}

	@Override
	public Set<SignalInfo> getPluginSignals() {
		Set<SignalInfo> signals = new HashSet<>();
		signals.add(new SignalInfo(CONNECTION_ESTABLISHED_SIGNAL, Dictionary.class));
		signals.add(new SignalInfo(CONNECTION_LOST_SIGNAL, Dictionary.class));
		return signals;
	}

	@Override
	public View onMainCreate(Activity activity) {
		connectivityManager = (ConnectivityManager) activity.getSystemService(Context.CONNECTIVITY_SERVICE);
		registerNetworkCallback();
		return null;
	}

	private void registerNetworkCallback() {
		if (connectivityManager == null) return;

		NetworkRequest request = new NetworkRequest.Builder()
				.addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
				.build();

		networkCallback = new ConnectivityManager.NetworkCallback() {
			@Override
			public void onAvailable(Network network) {
				// Network is ready. Process and cache it.
				updateNetworkCache(network);
				ConnectionInfo info = activeNetworkCache.get(network);
				if (info != null) {
					// Check if this new network is considered "active" (primary)
					Network activeNetwork = connectivityManager.getActiveNetwork();
					boolean isActive = (activeNetwork != null && activeNetwork.equals(network));

					info.setIsActive(isActive);

					emitSignal(CONNECTION_ESTABLISHED_SIGNAL, info.getRawData());
				}
			}

			@Override
			public void onCapabilitiesChanged(Network network, NetworkCapabilities networkCapabilities) {
				updateNetworkCache(network);
			}

			@Override
			public void onLost(Network network) {
				// Network lost. Retrieve last known info before removing.
				ConnectionInfo info = activeNetworkCache.get(network);

				if (info == null) {
					info = new ConnectionInfo();
					info.setConnectionType(ConnectionType.UNKNOWN);
					info.setIsMetered(false);
				}

				info.setIsActive(false);	// The lost network is not active anymore

				activeNetworkCache.remove(network);
				emitSignal(CONNECTION_LOST_SIGNAL, info.getRawData());
			}
		};

		connectivityManager.registerNetworkCallback(request, networkCallback);
	}

	private void updateNetworkCache(Network network) {
		if (connectivityManager == null) return;

		NetworkCapabilities caps = connectivityManager.getNetworkCapabilities(network);
		if (caps != null && caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
			ConnectionInfo info = getNetworkInfo(caps);
			activeNetworkCache.put(network, info);
		}
	}

	@UsedByGodot
	public Object[] get_connection_state() {
		Network activeNetwork = connectivityManager.getActiveNetwork();
		List<Dictionary> resultList = new ArrayList<>();

		for (Map.Entry<Network, ConnectionInfo> entry : activeNetworkCache.entrySet()) {
			Network net = entry.getKey();
			ConnectionInfo cachedInfo = entry.getValue();

			boolean isActive = (activeNetwork != null && activeNetwork.equals(net));
			cachedInfo.setIsActive(isActive);

			resultList.add(cachedInfo.getRawData());
		}

		return resultList.toArray();
	}

	private ConnectionInfo getNetworkInfo(NetworkCapabilities caps) {
		ConnectionInfo info = new ConnectionInfo();

		ConnectionType type = ConnectionType.UNKNOWN;
		boolean isMetered = false;

		if (caps != null) {
			if (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) type = ConnectionType.WIFI;
			else if (caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) type = ConnectionType.CELLULAR;
			else if (caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)) type = ConnectionType.ETHERNET;
			else if (caps.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH)) type = ConnectionType.BLUETOOTH;
			else if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) type = ConnectionType.VPN;

			isMetered = !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED);
		}

		info.setConnectionType(type);
		info.setIsMetered(isMetered);

		return info;
	}

	@Override
	public void onMainDestroy() {
		if (connectivityManager != null && networkCallback != null) {
			connectivityManager.unregisterNetworkCallback(networkCallback);
		}
		activeNetworkCache.clear();
	}
}
