//
// © 2025-present https://github.com/cengiz-pz
//

#import "connection_state_plugin.h"

#import "connection_state_plugin-Swift.h"

#import "connection_info.h"
#import "connection_state_logger.h"


const String CONNECTION_ESTABLISHED_SIGNAL = "connection_established";
const String CONNECTION_LOST_SIGNAL = "connection_lost";


ConnectionStatePlugin* ConnectionStatePlugin::instance = NULL;


void ConnectionStatePlugin::_bind_methods() {
	ClassDB::bind_method(D_METHOD("get_connection_state"), &ConnectionStatePlugin::get_connection_state);

	ADD_SIGNAL(MethodInfo(CONNECTION_ESTABLISHED_SIGNAL, PropertyInfo(Variant::DICTIONARY, "connection_info")));
	ADD_SIGNAL(MethodInfo(CONNECTION_LOST_SIGNAL, PropertyInfo(Variant::DICTIONARY, "connection_info")));
}

Array ConnectionStatePlugin::get_connection_state() {
	os_log_debug(connection_state_log, "::get_connection_state()");

	NSArray *states = [connection_state_monitor getCurrentState];
	Array godot_array;

	for (NSDictionary *info in states) {
		ConnectionInfo *connectionInfo = [[ConnectionInfo alloc] initWithDictionary:info];
		godot_array.push_back([connectionInfo getRawData]);
	}

	return godot_array;
}

ConnectionStatePlugin::ConnectionStatePlugin() {
	os_log_debug(connection_state_log, "Plugin singleton constructor");

	ERR_FAIL_COND(instance != NULL);

	instance = this;

	connection_state_monitor = [[ConnectionState alloc] init];

	// Bridge Swift Closures to Godot Signals
	connection_state_monitor.onConnectionEstablished = ^(NSDictionary *info) {
		// Capture 'this' pointer safely for use inside the C++ lambda bridge
		ConnectionStatePlugin *plugin_instance = instance;

		ConnectionInfo *connectionInfo = [[ConnectionInfo alloc] initWithDictionary:info];

		plugin_instance->call_deferred("emit_signal", CONNECTION_ESTABLISHED_SIGNAL, [connectionInfo getRawData]);
	};

	connection_state_monitor.onConnectionLost = ^(NSDictionary *info) {
		// Capture 'this' pointer safely for use inside the C++ lambda bridge
		ConnectionStatePlugin *plugin_instance = instance;
		
		ConnectionInfo *connectionInfo = [[ConnectionInfo alloc] initWithDictionary:info];

		plugin_instance->call_deferred("emit_signal", CONNECTION_LOST_SIGNAL, [connectionInfo getRawData]);
	};
}

ConnectionStatePlugin::~ConnectionStatePlugin() {
	os_log_debug(connection_state_log, "Plugin singleton destructor");

	connection_state_monitor = nil;

	if (instance == this) {
		instance = nullptr;
	}
}
