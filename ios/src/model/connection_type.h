//
// © 2025-present https://github.com/cengiz-pz
//

#ifndef connection_type_h
#define connection_type_h

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, ConnectionType) {
	ConnectionTypeUnknown = 0,
	ConnectionTypeWifi = 1,
	ConnectionTypeCellular = 2,
	ConnectionTypeEthernet = 3,
	ConnectionTypeBluetooth = 4,
	ConnectionTypeVpn = 5,
	ConnectionTypeLoopback = 6
};

#endif /* connection_type_h */
