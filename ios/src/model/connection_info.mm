//
// © 2025-present https://github.com/cengiz-pz
//

#import "connection_info.h"

#import "connection_state_plugin-Swift.h"

static String const kConnectionTypeProperty = String([[ConnectionState connectionTypeKey] UTF8String]);
static String const kIsActiveProperty = String([[ConnectionState isActiveKey] UTF8String]);
static String const kIsMeteredProperty = String([[ConnectionState isMeteredKey] UTF8String]);

static NSString * const nsConnectionTypeProperty = [ConnectionState connectionTypeKey];
static NSString * const nsIsActiveProperty = [ConnectionState isActiveKey];
static NSString * const nsIsMeteredProperty = [ConnectionState isMeteredKey];

@interface ConnectionInfo ()

@property (nonatomic) Dictionary data;

@end

@implementation ConnectionInfo

- (instancetype)initWithDictionary:(NSDictionary *)nsDict {
	self = [super init];
	if (self) {
		_data = Dictionary();
		_data[kConnectionTypeProperty] = [nsDict[nsConnectionTypeProperty] intValue];
		_data[kIsActiveProperty] = [nsDict[nsIsActiveProperty] boolValue];
		_data[kIsMeteredProperty] = [nsDict[nsIsMeteredProperty] boolValue];

	}
	return self;
}

- (void)setConnectionType:(ConnectionType)type {
	self.data[kConnectionTypeProperty] = type;
}

- (void)setIsActive:(BOOL)isActive {
	self.data[kIsActiveProperty] = isActive;
}

- (void)setIsMetered:(BOOL)isMetered {
	self.data[kIsMeteredProperty] = isMetered;
}

- (Dictionary)getRawData {
	return _data.duplicate();
}

@end
