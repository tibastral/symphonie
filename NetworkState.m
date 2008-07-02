//
//  NetworkState.m
//  sipPhone
//
//  Created by Daniel Braun on 02/07/08.
//  Copyright 2008 Ercom. All rights reserved.
//

#import "NetworkState.h"


@implementation NetworkState



static void scCallback(  SCDynamicStoreRef store, 
		       CFArrayRef changedKeys, 
		       void *info)
{
	//NSLog(@"sc callback\n");
	NSArray *ck=(NSArray *)changedKeys;
	int i, count = [ck count];
	for (i = 0; i < count; i++) {
		NSString *k = [ck objectAtIndex:i];
		CFPropertyListRef pv=SCDynamicStoreCopyValue (store, (CFStringRef)k);
		NSLog(@"for %@: %@\n", k, pv);
		NSLog(@"for %@, busy=%@ SSID %@, net=%@\n", k, [(id)pv valueForKey:@"Busy"], [(id)pv valueForKey:@"BSSID"], [(id)pv valueForKey:@"SSID_STR"]);
		NSData *bssid=[[[(id)pv valueForKey:@"BSSID"]retain]autorelease];
		NSString *ssidStr=[[[(id)pv valueForKey:@"SSID_STR"]retain]autorelease];
		NSNumber *busy= [(id)pv valueForKey:@"Busy"];
		
		CFRelease(pv);
	}
	
}

- (id) initWithClient:(NSObject  <NetworkStateClient> *) _client
{
	self=[self init];
	if (!self) return self;
	client=[_client retain];
	
	static SCDynamicStoreContext dynamicStoreContext ={ 0, NULL, NULL, NULL, NULL };
	dynamicStoreContext.info=(void *) self;
	scdref=SCDynamicStoreCreate ( NULL, (CFStringRef) @"symPhonie",
				     scCallback, 
				     &dynamicStoreContext );
	CFStringRef itfkey=SCDynamicStoreKeyCreateNetworkInterface(NULL, kSCDynamicStoreDomainState);
	CFPropertyListRef itfs=SCDynamicStoreCopyValue(scdref, itfkey);
	CFRelease(itfkey);
	if (!itfs) goto wifi_done;
	NSArray *itf=[(id)itfs valueForKey:@"Interfaces"];
	if (!itf) goto wifi_done;
	NSMutableArray *notif=[NSMutableArray arrayWithCapacity:5];
	int i, count = [itf count];
	for (i = 0; i < count; i++) {
		NSString * iface = [itf objectAtIndex:i];
		CFStringRef ik=SCDynamicStoreKeyCreateNetworkInterfaceEntity(NULL, kSCDynamicStoreDomainState, (CFStringRef) iface, kSCEntNetAirPort);
		[notif addObject:(NSString *)ik];
		CFRelease(ik);
	}
	BOOL ok=SCDynamicStoreSetNotificationKeys(scdref, (CFArrayRef)notif, NULL);
	if (!ok) {
		NSLog(@"SCDynamicStoreSetNotificationKeys failed :%d : %s\n", SCError(), SCErrorString(SCError()));
		goto wifi_done;
	}
	CFRunLoopSourceRef rls=SCDynamicStoreCreateRunLoopSource(NULL, scdref, 0);
	CFRunLoopAddSource([[NSRunLoop currentRunLoop]getCFRunLoop], rls, kCFRunLoopCommonModes);
	CFRelease(rls);
wifi_done:	
	return self;
}
- (void) registerLocation:(NSString *)name ssid:(NSString *)ssid interface:(NSString *)iface
{
}
@end
