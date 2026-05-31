//
// © 2025-present https://github.com/cengiz-pz
//

package org.godotengine.plugin.connectionstate;

import android.net.ConnectivityManager;
import android.net.Network;

import org.godotengine.plugin.connectionstate.model.ConnectionInfo;

import java.lang.reflect.Field;
import java.util.Map;

/**
 * Reflection-based test helpers for {@link ConnectionStatePlugin}.
 *
 * <p>All private fields in {@code ConnectionStatePlugin} that tests need to
 * inspect or pre-load are accessed here rather than scattered across test
 * classes. Keeping the reflective plumbing in one place means test methods
 * read as intent, not as boilerplate.
 *
 * <h2>Design notes</h2>
 * <ul>
 *   <li>When the {@code target} is a Mockito spy, its runtime class is a
 *       generated subclass of {@code ConnectionStatePlugin}. {@link #findField}
 *       therefore walks the full superclass chain so both plain instances and
 *       spies are handled uniformly.</li>
 *   <li>None of these helpers call production code paths — they manipulate
 *       state directly so tests can isolate specific behaviours without
 *       triggering the full Android lifecycle (e.g. {@code onMainCreate}).</li>
 * </ul>
 */
public final class ConnectionStatePluginFixture {

	// -------------------------------------------------------------------------
	// Factory
	// -------------------------------------------------------------------------

	/**
	 * Creates a bare {@link ConnectionStatePlugin} wired to the supplied
	 * (mocked) {@code Godot} instance. The {@code connectivityManager} field
	 * is left null; callers that need it should follow up with
	 * {@link #injectConnectivityManager}.
	 */
	public static ConnectionStatePlugin create(org.godotengine.godot.Godot godot) {
		return new ConnectionStatePlugin(godot);
	}

	// -------------------------------------------------------------------------
	// Field injection
	// -------------------------------------------------------------------------

	/**
	 * Writes {@code manager} directly into the plugin's private
	 * {@code connectivityManager} field, bypassing the
	 * {@code Activity.getSystemService()} call that normally sets it during
	 * {@code onMainCreate()}.
	 */
	public static void injectConnectivityManager(
			ConnectionStatePlugin plugin,
			ConnectivityManager manager) throws Exception {
		setField(plugin, "connectivityManager", manager);
	}

	/**
	 * Writes {@code callback} directly into the plugin's private
	 * {@code networkCallback} field so that {@code onMainDestroy()} can
	 * unregister it, or so tests can verify it is {@code null} before setup.
	 */
	public static void injectNetworkCallback(
			ConnectionStatePlugin plugin,
			ConnectivityManager.NetworkCallback callback) throws Exception {
		setField(plugin, "networkCallback", callback);
	}

	// -------------------------------------------------------------------------
	// Field reads
	// -------------------------------------------------------------------------

	/**
	 * Returns a live reference to the plugin's internal {@code activeNetworkCache}.
	 * Tests use this to:
	 * <ul>
	 *   <li>seed initial state via {@link #seedCache}; and</li>
	 *   <li>assert post-condition cache contents directly.</li>
	 * </ul>
	 *
	 * <p><strong>Note:</strong> the returned map is the real {@code ConcurrentHashMap}
	 * that production code also writes to during callbacks — mutations are
	 * immediately visible.
	 */
	@SuppressWarnings("unchecked")
	public static Map<Network, ConnectionInfo> getActiveNetworkCache(
			ConnectionStatePlugin plugin) throws Exception {
		return (Map<Network, ConnectionInfo>) getField(plugin, "activeNetworkCache");
	}

	// -------------------------------------------------------------------------
	// Cache helpers
	// -------------------------------------------------------------------------

	/**
	 * Inserts a single {@code (network → info)} pair into the plugin's cache
	 * without going through any callback. This is the primary way tests set up
	 * preconditions for {@code get_connection_state()}, {@code onLost()}, and
	 * {@code onCapabilitiesChanged()} scenarios.
	 */
	public static void seedCache(
			ConnectionStatePlugin plugin,
			Network network,
			ConnectionInfo info) throws Exception {
		getActiveNetworkCache(plugin).put(network, info);
	}

	/**
	 * Removes all entries from the plugin's cache.
	 * Useful to establish an empty-cache precondition independent of how the
	 * plugin was bootstrapped.
	 */
	public static void clearCache(ConnectionStatePlugin plugin) throws Exception {
		getActiveNetworkCache(plugin).clear();
	}

	// -------------------------------------------------------------------------
	// Reflection internals
	// -------------------------------------------------------------------------

	/**
	 * Walks the class hierarchy of {@code target} (including superclasses) to
	 * find a field named {@code name}, then sets its value on {@code target}.
	 *
	 * <p>Walking the hierarchy is required because Mockito spies are instances
	 * of a generated subclass; their fields are declared in the parent.
	 */
	private static void setField(Object target, String name, Object value) throws Exception {
		Field field = findField(target.getClass(), name);
		field.setAccessible(true);
		field.set(target, value);
	}

	/**
	 * Same hierarchy walk as {@link #setField}, but reads the field value.
	 */
	private static Object getField(Object target, String name) throws Exception {
		Field field = findField(target.getClass(), name);
		field.setAccessible(true);
		return field.get(target);
	}

	/**
	 * Traverses {@code clazz} and each of its superclasses until it finds a
	 * field with the given {@code name}.
	 *
	 * @throws NoSuchFieldException if no field with that name exists anywhere
	 *                              in the hierarchy up to (but not including)
	 *                              {@link Object}
	 */
	private static Field findField(Class<?> clazz, String name) throws NoSuchFieldException {
		for (Class<?> c = clazz; c != null && c != Object.class; c = c.getSuperclass()) {
			try {
				return c.getDeclaredField(name);
			} catch (NoSuchFieldException ignored) {
				// continue walking up
			}
		}
		throw new NoSuchFieldException(
				"No field '" + name + "' found in class hierarchy of " + clazz.getName());
	}

	// -------------------------------------------------------------------------

	private ConnectionStatePluginFixture() {
		// static utility class — no instances
	}
}
