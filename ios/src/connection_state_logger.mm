//
// © 2025-present https://github.com/cengiz-pz
//

#import "connection_state_logger.h"

// Define and initialize the shared os_log_t instance
os_log_t connection_state_log;

__attribute__((constructor)) // Automatically runs at program startup
static void initialize_connection_state_log(void) {
	connection_state_log = os_log_create("org.godotengine.plugin.connection_state", "ConnectionStatePlugin");
}
