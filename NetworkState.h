//
//  NetworkState.h
//  sipPhone
//
//  Created by Daniel Braun on 02/07/08.
//  Copyright 2008 Daniel Braun. All rights reserved.
//


/*
 * handle network state notification
 * also handles home/foreign detection
 */

#import <Cocoa/Cocoa.h>
#include <SystemConfiguration/SystemConfiguration.h>


@protocol NetworkStateClient
- (void) networkAvailable:(BOOL)av;
- (void) computerLocationChanged:(NSString *)location;
@end

@interface NetworkState : NSObject {
	SCDynamicStoreRef scdref;
	IBOutlet NSObject  <NetworkStateClient> * client;
	NSMutableDictionary *ifaces;
	BOOL changed;
	BOOL reachability;
}
- (id) init;
- (id) initWithClient:(NSObject  <NetworkStateClient> *) client;
- (void) setClient:(NSObject  <NetworkStateClient> *) client;
- (void) registerLocation:(NSString *)name ssid:(NSString *)ssid interface:(NSString *)iface; //....

- (BOOL) networkAvailable;
- (NSData *) bssid;
- (NSString *) ssidStr;
- (NSString *) mainIp;
- (NSString *) interfaceType;

@end
