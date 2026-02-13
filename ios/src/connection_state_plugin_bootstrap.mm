//
// © 2025-present https://github.com/cengiz-pz
//

#import <Foundation/Foundation.h>

#import "connection_state_plugin_bootstrap.h"
#import "connection_state_plugin.h"
#import "connection_state_logger.h"

#import "core/config/engine.h"


ConnectionStatePlugin *connection_state_plugin;


void connection_state_plugin_init() {
	os_log_debug(connection_state_log, "ConnectionStatePlugin: Initializing plugin at timestamp: %f", [[NSDate date] timeIntervalSince1970]);

	connection_state_plugin = memnew(ConnectionStatePlugin);
	Engine::get_singleton()->add_singleton(Engine::Singleton("ConnectionStatePlugin", connection_state_plugin));
	os_log_debug(connection_state_log, "ConnectionStatePlugin: Singleton registered");
}


void connection_state_plugin_deinit() {
	os_log_debug(connection_state_log, "ConnectionStatePlugin: Deinitializing plugin");
	connection_state_log = NULL; // Prevent accidental reuse

	if (connection_state_plugin) {
		memdelete(connection_state_plugin);
		connection_state_plugin = nullptr;
	}
}
