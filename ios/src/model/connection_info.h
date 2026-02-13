//
// © 2025-present https://github.com/cengiz-pz
//

#import <Foundation/Foundation.h>

#include "core/object/class_db.h"

#include "connection_type.h"

@interface ConnectionInfo : NSObject

- (instancetype)initWithDictionary:(NSDictionary *)nsDict;
- (void)setConnectionType:(ConnectionType)type;
- (void)setIsActive:(BOOL)isActive;
- (void)setIsMetered:(BOOL)isMetered;
- (Dictionary)getRawData;

@end
