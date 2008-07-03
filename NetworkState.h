//
//  NetworkState.h
//  sipPhone
//
//  Created by Daniel Braun on 02/07/08.
//  Copyright 2008 Ercom. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <SystemConfiguration/SystemConfiguration.h>


@protocol NetworkStateClient
- (void) networkAvailable:(BOOL)av bssid:(NSData *)ssid ssidString:(NSString *)ssidStr;
- (void) computerLocationChanged:(NSString *)location;
@end

@interface NetworkState : NSObject {
	SCDynamicStoreRef scdref;
	NSObject  <NetworkStateClient> * client;
	NSMutableDictionary *ifaces;
	BOOL changed;
}

- (id) initWithClient:(NSObject  <NetworkStateClient> *) client;
- (void) registerLocation:(NSString *)name ssid:(NSString *)ssid interface:(NSString *)iface; //....

@end
