//
// © 2025-present https://github.com/cengiz-pz
//

package org.godotengine.plugin.connectionstate;

import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.NetworkRequest;

import org.godotengine.godot.Dictionary;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.plugin.connectionstate.model.ConnectionInfo;
import org.godotengine.plugin.connectionstate.model.ConnectionInfoFixture;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.MockedConstruction;
import org.mockito.Mockito;
import org.mockito.junit.jupiter.MockitoExtension;

import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.assertAll;
import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.verify;

/**
 * Unit tests for {@link ConnectionStatePlugin}.
 *
 * <h2>Test strategy</h2>
 *
 * <p>{@code ConnectionStatePlugin} inherits from {@code GodotPlugin} and holds
 * references to Android framework objects ({@code ConnectivityManager},
 * {@code Network}, {@code NetworkCapabilities}). The test setup has three
 * moving parts:
 *
 * <ol>
 *   <li><strong>{@code CapturingPlugin} inner class, not a Mockito spy.</strong>
 *       {@code GodotPlugin.emitSignal()} is {@code protected}, so it cannot be
 *       stubbed or verified from a different-package test class — doing so causes
 *       a Java compile error. The solution is a package-private static inner
 *       class that <em>extends</em> {@code ConnectionStatePlugin} and
 *       {@code @Override}s {@code emitSignal()}, which is always permitted for
 *       subclasses. The override records every emission into plain lists that
 *       the test can inspect without any Mockito involvement.</li>
 *
 *   <li><strong>Direct field injection.</strong> {@code connectivityManager} is
 *       normally set during {@code onMainCreate()}. Tests inject the mock via
 *       {@link ConnectionStatePluginFixture#injectConnectivityManager} so that
 *       the Android activity lifecycle is never triggered.</li>
 *
 *   <li><strong>Callback bootstrap.</strong> {@code registerNetworkCallback()}
 *       is private and calls {@code new NetworkRequest.Builder()} — a chained
 *       builder whose Android SDK stub methods return {@code null}, which causes
 *       a {@code NullPointerException} on {@code .build()}. We wrap the call in
 *       a {@code MockedConstruction<NetworkRequest.Builder>} that makes the
 *       builder return {@code this} from every fluent method, then capture the
 *       real {@code NetworkCallback} via {@code ArgumentCaptor}.</li>
 * </ol>
 *
 * <p>Because {@code CapturingPlugin} is a genuine subclass, the anonymous
 * {@code NetworkCallback} created by {@code registerNetworkCallback()} closes
 * over it as {@code this}, so all {@code emitSignal()} calls produced by the
 * callback are captured in {@link CapturingPlugin#emittedSignalNames} and
 * {@link CapturingPlugin#emittedPayloads}.
 */
@ExtendWith(MockitoExtension.class)
@DisplayName("ConnectionStatePlugin")
class ConnectionStatePluginTest {

	// =========================================================================
	// CapturingPlugin — test subclass replacing the Mockito spy
	// =========================================================================

	/**
	 * Subclass of {@link ConnectionStatePlugin} that overrides the
	 * {@code protected} {@code emitSignal()} method to record emissions
	 * instead of forwarding them to Godot's JNI layer.
	 *
	 * <p>Because {@code emitSignal} is {@code protected} in {@code GodotPlugin},
	 * it cannot be stubbed or verified from an unrelated test class. This
	 * subclass sidesteps the access restriction entirely: a subclass may always
	 * override a {@code protected} method, regardless of package.
	 */
	private static class CapturingPlugin extends ConnectionStatePlugin {

		final List<String> emittedSignalNames = new ArrayList<>();
		final List<Dictionary> emittedPayloads = new ArrayList<>();

		CapturingPlugin(Godot godot) {
			super(godot);
		}

		/**
		 * Records the signal name and its {@link Dictionary} payload (the
		 * first vararg element, if any) without touching Godot/JNI at all.
		 */
		@Override
		protected void emitSignal(String signalName, Object... signalArgs) {
			emittedSignalNames.add(signalName);
			if (signalArgs != null && signalArgs.length > 0
					&& signalArgs[0] instanceof Dictionary) {
				emittedPayloads.add((Dictionary) signalArgs[0]);
			}
		}

		/** The name of the most recently emitted signal, or {@code null}. */
		String lastSignalName() {
			return emittedSignalNames.isEmpty()
					? null
					: emittedSignalNames.get(emittedSignalNames.size() - 1);
		}

		/** The payload of the most recently emitted signal, or {@code null}. */
		Dictionary lastPayload() {
			return emittedPayloads.isEmpty()
					? null
					: emittedPayloads.get(emittedPayloads.size() - 1);
		}
	}

	// =========================================================================
	// Mocks
	// =========================================================================

	@Mock
	private Godot mockGodot;

	@Mock
	private ConnectivityManager mockConnectivityManager;

	@Mock
	private Network mockNetwork;

	@Mock
	private Network mockSecondNetwork;

	@Mock
	private NetworkCapabilities mockCapabilities;

	// =========================================================================
	// System under test & shared state
	// =========================================================================

	/** Instance of {@link CapturingPlugin} recreated before each test. */
	private CapturingPlugin capturingPlugin;

	/** Callback captured by {@link #bootstrapCallback()}. */
	private ConnectivityManager.NetworkCallback capturedCallback;

	// =========================================================================
	// Set-up
	// =========================================================================

	@BeforeEach
	void setUp() throws Exception {
		capturingPlugin = new CapturingPlugin(mockGodot);
		ConnectionStatePluginFixture.injectConnectivityManager(
				capturingPlugin, mockConnectivityManager);
	}

	// =========================================================================
	// Bootstrap helper
	// =========================================================================

	/**
	 * Invokes the private {@code registerNetworkCallback()} method on
	 * {@link #capturingPlugin} so that the anonymous {@code NetworkCallback} is
	 * created with the {@code CapturingPlugin} as its enclosing {@code this}.
	 *
	 * <p>{@code NetworkRequest.Builder} is mocked via
	 * {@code MockedConstruction} so that the fluent chain
	 * {@code new Builder().addCapability(...).build()} succeeds even though the
	 * Android SDK stub's methods return {@code null} under
	 * {@code isReturnDefaultValues = true}.
	 *
	 * <p>The real callback is captured via {@code ArgumentCaptor} and stored in
	 * {@link #capturedCallback}. Invocation counts on
	 * {@code mockConnectivityManager} are cleared immediately afterwards so
	 * that test-level {@code verify()} calls are not polluted by the bootstrap
	 * interaction.
	 */
	private void bootstrapCallback() throws Exception {
		try (MockedConstruction<NetworkRequest.Builder> ignored =
				Mockito.mockConstruction(NetworkRequest.Builder.class, (mock, ctx) -> {
					// Make the fluent builder return itself so .build() is reached
					Mockito.when(mock.addCapability(anyInt())).thenReturn(mock);
					// build() can return null — the mocked ConnectivityManager ignores it
					Mockito.when(mock.build()).thenReturn(null);
				})) {

			Method registerMethod = ConnectionStatePlugin.class
					.getDeclaredMethod("registerNetworkCallback");
			registerMethod.setAccessible(true);
			registerMethod.invoke(capturingPlugin);

			ArgumentCaptor<ConnectivityManager.NetworkCallback> callbackCaptor =
					ArgumentCaptor.forClass(ConnectivityManager.NetworkCallback.class);
			verify(mockConnectivityManager)
					.registerNetworkCallback(any(), callbackCaptor.capture());
			capturedCallback = callbackCaptor.getValue();
		}

		// Reset counts so that later verify() calls in tests are not polluted
		// by the bootstrap interaction with mockConnectivityManager.
		clearInvocations(mockConnectivityManager);
	}

	// =========================================================================
	// Convenience accessors
	// =========================================================================

	/** Shorthand for reading the plugin's live {@code activeNetworkCache}. */
	private Map<Network, ConnectionInfo> cache() throws Exception {
		return ConnectionStatePluginFixture.getActiveNetworkCache(capturingPlugin);
	}

	/**
	 * Configures {@code mockConnectivityManager} and {@code mockCapabilities}
	 * so that a call to the plugin's {@code updateNetworkCache(mockNetwork)}
	 * will produce a cache entry with the specified transport type and metered
	 * flag.
	 *
	 * <p>The transport stubs are registered with {@code lenient()} because the
	 * production code evaluates them in an {@code if/else if} chain and
	 * short-circuits on the first {@code true}. For example, when testing
	 * WIFI, {@code hasTransport(CELLULAR/ETHERNET/BLUETOOTH/VPN)} is never
	 * reached; those stubs are intentional defensive setup, not mistakes, so
	 * Mockito's strict-stub check must not flag them.
	 *
	 * @param transport one of the {@code NetworkCapabilities.TRANSPORT_*} constants
	 * @param metered   {@code true} if the network should be reported as metered
	 */
	private void setUpNetworkCapabilities(int transport, boolean metered) {
		Mockito.when(mockConnectivityManager.getNetworkCapabilities(mockNetwork))
				.thenReturn(mockCapabilities);
		Mockito.lenient()
				.when(mockCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET))
				.thenReturn(true);

		for (int t : new int[]{
				NetworkCapabilities.TRANSPORT_WIFI,
				NetworkCapabilities.TRANSPORT_CELLULAR,
				NetworkCapabilities.TRANSPORT_ETHERNET,
				NetworkCapabilities.TRANSPORT_BLUETOOTH,
				NetworkCapabilities.TRANSPORT_VPN}) {
			// lenient: only stubs up to and including the matching transport
			// are consumed; later ones are never reached due to short-circuit.
			Mockito.lenient().when(mockCapabilities.hasTransport(t)).thenReturn(t == transport);
		}

		// NET_CAPABILITY_NOT_METERED is PRESENT when the network is NOT metered.
		// Registered as lenient because some test paths (e.g. caps returning
		// false for INTERNET) never reach getNetworkInfo() and won't consume it.
		Mockito.lenient()
				.when(mockCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED))
				.thenReturn(!metered);
	}

	// =========================================================================
	// Plugin metadata
	// =========================================================================

	@Nested
	@DisplayName("Plugin metadata")
	class PluginMetadataTest {

		@Test
		@DisplayName("getPluginName() returns the simple class name 'ConnectionStatePlugin'")
		void getPluginName_returnsSimpleClassName() {
			assertEquals("ConnectionStatePlugin", capturingPlugin.getPluginName());
		}

		@Test
		@DisplayName("getPluginSignals() returns exactly two signals")
		void getPluginSignals_returnsExactlyTwoSignals() {
			assertEquals(2, capturingPlugin.getPluginSignals().size());
		}

		@Test
		@DisplayName("getPluginSignals() includes the 'connection_established' signal")
		void getPluginSignals_includesConnectionEstablished() {
			assertTrue(signalNames().contains("connection_established"));
		}

		@Test
		@DisplayName("getPluginSignals() includes the 'connection_lost' signal")
		void getPluginSignals_includesConnectionLost() {
			assertTrue(signalNames().contains("connection_lost"));
		}

		private Set<String> signalNames() {
			return capturingPlugin.getPluginSignals()
					.stream()
					.map(SignalInfo::getName)
					.collect(Collectors.toSet());
		}
	}

	// =========================================================================
	// get_connection_state()
	// =========================================================================

	@Nested
	@DisplayName("get_connection_state()")
	class GetConnectionStateTest {

		@Test
		@DisplayName("returns an empty array when the cache contains no networks")
		void emptyCache_returnsEmptyArray() {
			Object[] result = capturingPlugin.get_connection_state();
			assertEquals(0, result.length);
		}

		@Test
		@DisplayName("returns one element per cached network")
		void singleCachedNetwork_returnsOneElement() throws Exception {
			ConnectionStatePluginFixture.seedCache(
					capturingPlugin, mockNetwork, ConnectionInfoFixture.wifiActive());

			Object[] result = capturingPlugin.get_connection_state();

			assertEquals(1, result.length);
		}

		@Test
		@DisplayName("returns one element per network when multiple networks are cached")
		void multipleCachedNetworks_returnsOneElementEach() throws Exception {
			ConnectionStatePluginFixture.seedCache(
					capturingPlugin, mockNetwork, ConnectionInfoFixture.wifiActive());
			ConnectionStatePluginFixture.seedCache(
					capturingPlugin, mockSecondNetwork,
					ConnectionInfoFixture.cellularMeteredActive());

			Object[] result = capturingPlugin.get_connection_state();

			assertEquals(2, result.length);
		}

		@Test
		@DisplayName("each element is a Dictionary")
		void eachElementIsADictionary() throws Exception {
			ConnectionStatePluginFixture.seedCache(
					capturingPlugin, mockNetwork, ConnectionInfoFixture.wifiActive());

			Object[] result = capturingPlugin.get_connection_state();

			assertInstanceOf(Dictionary.class, result[0]);
		}

		@Test
		@DisplayName("marks the network matching getActiveNetwork() as is_active=true")
		void matchingActiveNetwork_isMarkedActive() throws Exception {
			Mockito.when(mockConnectivityManager.getActiveNetwork()).thenReturn(mockNetwork);
			ConnectionStatePluginFixture.seedCache(
					capturingPlugin, mockNetwork, ConnectionInfoFixture.wifiInactive());

			Object[] result = capturingPlugin.get_connection_state();

			Dictionary dict = (Dictionary) result[0];
			assertEquals(true, dict.get("is_active"),
					"network matching getActiveNetwork() must be reported as active");
		}

		@Test
		@DisplayName("marks every network as is_active=false when getActiveNetwork() returns null")
		void noActiveNetwork_allMarkedInactive() throws Exception {
			Mockito.when(mockConnectivityManager.getActiveNetwork()).thenReturn(null);
			ConnectionStatePluginFixture.seedCache(
					capturingPlugin, mockNetwork, ConnectionInfoFixture.wifiActive());

			Object[] result = capturingPlugin.get_connection_state();

			Dictionary dict = (Dictionary) result[0];
			assertEquals(false, dict.get("is_active"),
					"when no active network exists all cached entries must be inactive");
		}

		@Test
		@DisplayName("does not modify the live cache — returned dictionaries are copies")
		void returnedDictionariesAreDefensiveCopies() throws Exception {
			ConnectionStatePluginFixture.seedCache(
					capturingPlugin, mockNetwork, ConnectionInfoFixture.wifiActive());

			Object[] result = capturingPlugin.get_connection_state();
			((Dictionary) result[0]).put("connection_type", 999);

			// Fetching again must still show the original type
			Object[] result2 = capturingPlugin.get_connection_state();
			assertEquals(1, ((Dictionary) result2[0]).get("connection_type"),
					"mutating the returned dictionary must not affect the cached entry");
		}
	}

	// =========================================================================
	// onMainDestroy()
	// =========================================================================

	@Nested
	@DisplayName("onMainDestroy()")
	class OnMainDestroyTest {

		@Test
		@DisplayName("clears the entire active-network cache")
		void clearsActiveNetworkCache() throws Exception {
			ConnectionStatePluginFixture.seedCache(
					capturingPlugin, mockNetwork, ConnectionInfoFixture.wifiActive());
			ConnectionStatePluginFixture.seedCache(
					capturingPlugin, mockSecondNetwork,
					ConnectionInfoFixture.cellularMeteredActive());

			capturingPlugin.onMainDestroy();

			assertEquals(0, cache().size(), "cache must be empty after destroy");
		}

		@Test
		@DisplayName("unregisters the network callback when both CM and callback are present")
		void unregistersNetworkCallback_whenBothArePresent() throws Exception {
			bootstrapCallback(); // populates capturedCallback on capturingPlugin

			capturingPlugin.onMainDestroy();

			verify(mockConnectivityManager).unregisterNetworkCallback(capturedCallback);
		}

		@Test
		@DisplayName("does not throw when networkCallback is null (callback never set)")
		void doesNotThrow_whenNetworkCallbackIsNull() {
			// connectivityManager is set but networkCallback was never assigned
			assertDoesNotThrow(
					() -> capturingPlugin.onMainDestroy(),
					"onMainDestroy() must be safe to call before the callback is registered");
		}
	}

	// =========================================================================
	// NetworkCallback — onAvailable()
	// =========================================================================

	@Nested
	@DisplayName("NetworkCallback.onAvailable()")
	class OnAvailableTest {

		@BeforeEach
		void bootstrap() throws Exception {
			bootstrapCallback();
		}

		// -- Cache management --------------------------------------------------

		@Test
		@DisplayName("adds the network to the cache when capabilities include INTERNET")
		void addsNetworkToCache_whenCapabilitiesHaveInternet() throws Exception {
			setUpNetworkCapabilities(NetworkCapabilities.TRANSPORT_WIFI, false);

			capturedCallback.onAvailable(mockNetwork);

			assertTrue(cache().containsKey(mockNetwork));
		}

		@Test
		@DisplayName("does NOT add the network to the cache when getNetworkCapabilities() returns null")
		void doesNotAddToCache_whenCapabilitiesAreNull() throws Exception {
			Mockito.when(mockConnectivityManager.getNetworkCapabilities(mockNetwork))
					.thenReturn(null);

			capturedCallback.onAvailable(mockNetwork);

			assertFalse(cache().containsKey(mockNetwork));
		}

		@Test
		@DisplayName("does NOT add the network to the cache when INTERNET capability is absent")
		void doesNotAddToCache_whenInternetCapabilityAbsent() throws Exception {
			Mockito.when(mockConnectivityManager.getNetworkCapabilities(mockNetwork))
					.thenReturn(mockCapabilities);
			Mockito.when(mockCapabilities.hasCapability(
					NetworkCapabilities.NET_CAPABILITY_INTERNET)).thenReturn(false);

			capturedCallback.onAvailable(mockNetwork);

			assertFalse(cache().containsKey(mockNetwork));
		}

		// -- is_active flag in cache -------------------------------------------

		@Test
		@DisplayName("sets is_active=true in cache when network equals getActiveNetwork()")
		void setsIsActiveTrue_whenNetworkIsActive() throws Exception {
			setUpNetworkCapabilities(NetworkCapabilities.TRANSPORT_WIFI, false);
			Mockito.when(mockConnectivityManager.getActiveNetwork()).thenReturn(mockNetwork);

			capturedCallback.onAvailable(mockNetwork);

			assertEquals(true, cache().get(mockNetwork).getRawData().get("is_active"),
					"active network must be marked is_active=true in cache");
		}

		@Test
		@DisplayName("sets is_active=false in cache when network is NOT the active one")
		void setsIsActiveFalse_whenNetworkIsNotActive() throws Exception {
			setUpNetworkCapabilities(NetworkCapabilities.TRANSPORT_WIFI, false);
			Mockito.when(mockConnectivityManager.getActiveNetwork()).thenReturn(null);

			capturedCallback.onAvailable(mockNetwork);

			assertEquals(false, cache().get(mockNetwork).getRawData().get("is_active"),
					"non-primary network must be marked is_active=false in cache");
		}

		// -- Signal emission ---------------------------------------------------

		@Test
		@DisplayName("emits 'connection_established' when the network is cached successfully")
		void emitsConnectionEstablishedSignal_onSuccessfulCache() throws Exception {
			setUpNetworkCapabilities(NetworkCapabilities.TRANSPORT_WIFI, false);

			capturedCallback.onAvailable(mockNetwork);

			assertEquals(
					ConnectionStatePlugin.CONNECTION_ESTABLISHED_SIGNAL,
					capturingPlugin.lastSignalName(),
					"connection_established must be emitted after a successful cache update");
		}

		@Test
		@DisplayName("does NOT emit any signal when the network cannot be cached")
		void doesNotEmitSignal_whenNetworkNotCacheable() throws Exception {
			Mockito.when(mockConnectivityManager.getNetworkCapabilities(mockNetwork))
					.thenReturn(null);

			capturedCallback.onAvailable(mockNetwork);

			assertTrue(capturingPlugin.emittedSignalNames.isEmpty(),
					"no signal must be emitted when the network cannot be added to cache");
		}

		// -- Signal payload ----------------------------------------------------

		@Test
		@DisplayName("emitted signal payload has is_active=true when network equals getActiveNetwork()")
		void signalPayload_isActiveTrue_whenNetworkIsActive() throws Exception {
			setUpNetworkCapabilities(NetworkCapabilities.TRANSPORT_WIFI, false);
			Mockito.when(mockConnectivityManager.getActiveNetwork()).thenReturn(mockNetwork);

			capturedCallback.onAvailable(mockNetwork);

			assertEquals(true, capturingPlugin.lastPayload().get("is_active"),
					"signal payload must report the network as active");
		}

		@Test
		@DisplayName("emitted signal payload has is_active=false when network is NOT the active one")
		void signalPayload_isActiveFalse_whenNetworkIsNotActive() throws Exception {
			setUpNetworkCapabilities(NetworkCapabilities.TRANSPORT_WIFI, false);
			Mockito.when(mockConnectivityManager.getActiveNetwork()).thenReturn(null);

			capturedCallback.onAvailable(mockNetwork);

			assertEquals(false, capturingPlugin.lastPayload().get("is_active"),
					"signal payload must report the network as inactive");
		}
	}

	// =========================================================================
	// Transport and metered detection
	// =========================================================================

	@Nested
	@DisplayName("Transport and metered detection (via onAvailable)")
	class TransportDetectionTest {

		@BeforeEach
		void bootstrap() throws Exception {
			bootstrapCallback();
		}

		@Test
		@DisplayName("TRANSPORT_WIFI → connection_type = 1 (WIFI)")
		void detectsWifiTransport() throws Exception {
			setUpNetworkCapabilities(NetworkCapabilities.TRANSPORT_WIFI, false);
			capturedCallback.onAvailable(mockNetwork);
			assertEquals(1, cachedConnectionType());
		}

		@Test
		@DisplayName("TRANSPORT_CELLULAR → connection_type = 2 (CELLULAR)")
		void detectsCellularTransport() throws Exception {
			setUpNetworkCapabilities(NetworkCapabilities.TRANSPORT_CELLULAR, false);
			capturedCallback.onAvailable(mockNetwork);
			assertEquals(2, cachedConnectionType());
		}

		@Test
		@DisplayName("TRANSPORT_ETHERNET → connection_type = 3 (ETHERNET)")
		void detectsEthernetTransport() throws Exception {
			setUpNetworkCapabilities(NetworkCapabilities.TRANSPORT_ETHERNET, false);
			capturedCallback.onAvailable(mockNetwork);
			assertEquals(3, cachedConnectionType());
		}

		@Test
		@DisplayName("TRANSPORT_BLUETOOTH → connection_type = 4 (BLUETOOTH)")
		void detectsBluetoothTransport() throws Exception {
			setUpNetworkCapabilities(NetworkCapabilities.TRANSPORT_BLUETOOTH, false);
			capturedCallback.onAvailable(mockNetwork);
			assertEquals(4, cachedConnectionType());
		}

		@Test
		@DisplayName("TRANSPORT_VPN → connection_type = 5 (VPN)")
		void detectsVpnTransport() throws Exception {
			setUpNetworkCapabilities(NetworkCapabilities.TRANSPORT_VPN, false);
			capturedCallback.onAvailable(mockNetwork);
			assertEquals(5, cachedConnectionType());
		}

		@Test
		@DisplayName("falls back to connection_type = 0 (UNKNOWN) when no recognized transport")
		void fallsBackToUnknown_whenNoRecognizedTransport() throws Exception {
			Mockito.when(mockConnectivityManager.getNetworkCapabilities(mockNetwork))
					.thenReturn(mockCapabilities);
			Mockito.when(mockCapabilities.hasCapability(
					NetworkCapabilities.NET_CAPABILITY_INTERNET)).thenReturn(true);
			Mockito.when(mockCapabilities.hasTransport(anyInt())).thenReturn(false);

			capturedCallback.onAvailable(mockNetwork);

			assertEquals(0, cachedConnectionType(),
					"unrecognized transport must fall back to UNKNOWN (0)");
		}

		@Test
		@DisplayName("absence of NET_CAPABILITY_NOT_METERED → is_metered = true")
		void meteredNetwork_isReportedAsMetered() throws Exception {
			setUpNetworkCapabilities(NetworkCapabilities.TRANSPORT_CELLULAR, true);
			capturedCallback.onAvailable(mockNetwork);
			assertEquals(true, cachedIsMetered());
		}

		@Test
		@DisplayName("presence of NET_CAPABILITY_NOT_METERED → is_metered = false")
		void unmeteredNetwork_isReportedAsUnmetered() throws Exception {
			setUpNetworkCapabilities(NetworkCapabilities.TRANSPORT_WIFI, false);
			capturedCallback.onAvailable(mockNetwork);
			assertEquals(false, cachedIsMetered());
		}

		// -- Helpers -----------------------------------------------------------

		private Object cachedConnectionType() throws Exception {
			return cache().get(mockNetwork).getRawData().get("connection_type");
		}

		private Object cachedIsMetered() throws Exception {
			return cache().get(mockNetwork).getRawData().get("is_metered");
		}
	}

	// =========================================================================
	// NetworkCallback — onCapabilitiesChanged()
	// =========================================================================

	@Nested
	@DisplayName("NetworkCallback.onCapabilitiesChanged()")
	class OnCapabilitiesChangedTest {

		@BeforeEach
		void bootstrap() throws Exception {
			bootstrapCallback();
		}

		@Test
		@DisplayName("updates the cached entry when transport changes")
		void updatesCache_whenTransportChanges() throws Exception {
			// Pre-seed as Wi-Fi
			ConnectionStatePluginFixture.seedCache(
					capturingPlugin, mockNetwork, ConnectionInfoFixture.wifiActive());

			// Now capabilities report CELLULAR
			setUpNetworkCapabilities(NetworkCapabilities.TRANSPORT_CELLULAR, true);
			capturedCallback.onCapabilitiesChanged(mockNetwork, mockCapabilities);

			assertEquals(2, cache().get(mockNetwork).getRawData().get("connection_type"),
					"cache entry must be updated to CELLULAR after capabilities change");
		}

		@Test
		@DisplayName("replaces an existing cache entry with the new capability data")
		void replacesExistingEntry_withUpdatedCapabilityData() throws Exception {
			ConnectionStatePluginFixture.seedCache(
					capturingPlugin, mockNetwork, ConnectionInfoFixture.wifiActive());

			// Capabilities change to metered CELLULAR
			setUpNetworkCapabilities(NetworkCapabilities.TRANSPORT_CELLULAR, true);
			capturedCallback.onCapabilitiesChanged(mockNetwork, mockCapabilities);

			Dictionary updated = cache().get(mockNetwork).getRawData();
			assertAll(
					() -> assertEquals(2, updated.get("connection_type"), "connection_type"),
					() -> assertEquals(true, updated.get("is_metered"), "is_metered"));
		}

		@Test
		@DisplayName("preserves the existing cache entry when updated caps have no INTERNET")
		void preservesExistingEntry_whenUpdatedCapsLackInternet() throws Exception {
			// updateNetworkCache() only *puts* inside the
			// "if (caps != null && hasCapability(INTERNET))" guard -- it has no
			// remove path.  When that guard is false, the existing entry is
			// simply left untouched (the network is only evicted by onLost()).
			ConnectionStatePluginFixture.seedCache(
					capturingPlugin, mockNetwork, ConnectionInfoFixture.wifiActive());

			Mockito.when(mockConnectivityManager.getNetworkCapabilities(mockNetwork))
					.thenReturn(mockCapabilities);
			Mockito.when(mockCapabilities.hasCapability(
					NetworkCapabilities.NET_CAPABILITY_INTERNET)).thenReturn(false);

			capturedCallback.onCapabilitiesChanged(mockNetwork, mockCapabilities);

			assertTrue(cache().containsKey(mockNetwork),
					"existing cache entry must be preserved -- updateNetworkCache does not remove");
			assertEquals(1, cache().get(mockNetwork).getRawData().get("connection_type"),
					"connection_type must remain WIFI (1) -- the entry was not overwritten");
		}

		@Test
		@DisplayName("does not emit any signal (capabilities change is cache-only)")
		void doesNotEmitSignal_onCapabilitiesChange() throws Exception {
			setUpNetworkCapabilities(NetworkCapabilities.TRANSPORT_WIFI, false);

			capturedCallback.onCapabilitiesChanged(mockNetwork, mockCapabilities);

			assertTrue(capturingPlugin.emittedSignalNames.isEmpty(),
					"onCapabilitiesChanged must not emit any signal — it is cache-only");
		}
	}

	// =========================================================================
	// NetworkCallback — onLost()
	// =========================================================================

	@Nested
	@DisplayName("NetworkCallback.onLost()")
	class OnLostTest {

		@BeforeEach
		void bootstrap() throws Exception {
			bootstrapCallback();
		}

		// -- Cache management --------------------------------------------------

		@Test
		@DisplayName("removes the network from the cache")
		void removesNetworkFromCache() throws Exception {
			ConnectionStatePluginFixture.seedCache(
					capturingPlugin, mockNetwork, ConnectionInfoFixture.wifiActive());

			capturedCallback.onLost(mockNetwork);

			assertFalse(cache().containsKey(mockNetwork),
					"lost network must be removed from the active-network cache");
		}

		@Test
		@DisplayName("does not affect other cached networks when one is lost")
		void doesNotAffectOtherCachedNetworks() throws Exception {
			ConnectionStatePluginFixture.seedCache(
					capturingPlugin, mockNetwork, ConnectionInfoFixture.wifiActive());
			ConnectionStatePluginFixture.seedCache(
					capturingPlugin, mockSecondNetwork,
					ConnectionInfoFixture.cellularMeteredActive());

			capturedCallback.onLost(mockNetwork);

			assertTrue(cache().containsKey(mockSecondNetwork),
					"the second network must remain in cache after an unrelated loss");
		}

		// -- Signal emission ---------------------------------------------------

		@Test
		@DisplayName("emits 'connection_lost' signal for a previously cached network")
		void emitsConnectionLostSignal_forCachedNetwork() throws Exception {
			ConnectionStatePluginFixture.seedCache(
					capturingPlugin, mockNetwork, ConnectionInfoFixture.wifiActive());

			capturedCallback.onLost(mockNetwork);

			assertEquals(
					ConnectionStatePlugin.CONNECTION_LOST_SIGNAL,
					capturingPlugin.lastSignalName(),
					"connection_lost must be emitted when a cached network is lost");
		}

		@Test
		@DisplayName("emits 'connection_lost' signal even when the network was never cached")
		void emitsConnectionLostSignal_evenWhenNetworkWasNeverCached() {
			// mockNetwork was never seeded into the cache
			capturedCallback.onLost(mockNetwork);

			assertEquals(
					ConnectionStatePlugin.CONNECTION_LOST_SIGNAL,
					capturingPlugin.lastSignalName(),
					"connection_lost must be emitted even for uncached networks");
		}

		// -- Signal payload — is_active ----------------------------------------

		@Test
		@DisplayName("signal payload has is_active=false for a previously cached network")
		void signalPayload_isActiveFalse_forCachedNetwork() throws Exception {
			// Seed as active so the transition to false is observable
			ConnectionStatePluginFixture.seedCache(
					capturingPlugin, mockNetwork, ConnectionInfoFixture.wifiActive());

			capturedCallback.onLost(mockNetwork);

			assertEquals(false, capturingPlugin.lastPayload().get("is_active"),
					"is_active must be false in the connection_lost signal payload");
		}

		// -- Signal payload — fallback info for uncached network ---------------

		@Test
		@DisplayName("signal payload has connection_type=0 (UNKNOWN) when network was never cached")
		void signalPayload_connectionTypeUnknown_whenNetworkWasNeverCached() {
			capturedCallback.onLost(mockNetwork);

			assertEquals(0, capturingPlugin.lastPayload().get("connection_type"),
					"connection_type must fall back to UNKNOWN (0) for an uncached network");
		}

		@Test
		@DisplayName("signal payload has is_metered=false when network was never cached")
		void signalPayload_isMeteredFalse_whenNetworkWasNeverCached() {
			capturedCallback.onLost(mockNetwork);

			assertEquals(false, capturingPlugin.lastPayload().get("is_metered"),
					"is_metered must default to false for an uncached network");
		}

		@Test
		@DisplayName("signal payload preserves the cached connection_type when network was in cache")
		void signalPayload_preservesCachedConnectionType() throws Exception {
			ConnectionStatePluginFixture.seedCache(
					capturingPlugin, mockNetwork, ConnectionInfoFixture.ethernetActive());

			capturedCallback.onLost(mockNetwork);

			assertEquals(3, capturingPlugin.lastPayload().get("connection_type"),
					"connection_type in the signal must match the last cached value (ETHERNET=3)");
		}
	}
}
