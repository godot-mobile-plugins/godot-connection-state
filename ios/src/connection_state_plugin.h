//
// © 2025-present https://github.com/cengiz-pz
//

#ifndef connection_state_plugin_h
#define connection_state_plugin_h

#import <Foundation/Foundation.h>

#include "core/object/object.h"
#include "core/object/class_db.h"


@class ConnectionState;


extern const String CONNECTION_ESTABLISHED_SIGNAL;
extern const String CONNECTION_LOST_SIGNAL;


class ConnectionStatePlugin : public Object {
	GDCLASS(ConnectionStatePlugin, Object);

private:
	static ConnectionStatePlugin* instance; // Singleton instance
	ConnectionState *connection_state_monitor;

	Array get_connection_state();

	static void _bind_methods();

public:

	ConnectionStatePlugin();
	~ConnectionStatePlugin();
};

#endif /* connection_state_plugin_h */
