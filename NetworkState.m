//
//  NetworkState.m
//  sipPhone
//
//  Created by Daniel Braun on 02/07/08.
//  Copyright 2008 Ercom. All rights reserved.
//

#import "NetworkState.h"


@implementation NetworkState

#pragma mark -
#pragma mark ** mark misc carbon helper **

static OSStatus MoreSCToOSStatus(int scErr)
// See comment in header.
{
	// I may eventually work out a transform here.  For now, let's just return 
	// the positive error code.
	return scErr;
}

static OSStatus MoreSCErrorBoolean(Boolean mustBeTrue)
// See comment in header.
{
	OSStatus err;
	int scErr;
	
	err = noErr;
	if ( ! mustBeTrue ) {
		scErr = SCError();
		if (scErr == kSCStatusOK) {
			scErr = kSCStatusFailed;
		}
		err = MoreSCToOSStatus(scErr);
	}
	return err;
}

static OSStatus MoreSCError(const void *value)
// See comment in header.
{
	return MoreSCErrorBoolean(value != NULL);
}

extern OSStatus CFQErrorBoolean(Boolean shouldBeTrue)
{
	OSStatus err;
	
	err = noErr;
	if (!shouldBeTrue) {
		err = coreFoundationUnknownErr;
	}
	return err;
}

extern OSStatus CFQError(const void *shouldBeNotNULL)
{
	return CFQErrorBoolean(shouldBeNotNULL != NULL);
}


extern CFTypeRef CFQRetain(CFTypeRef cf)
// See comment in header.
{
	if (cf != NULL) {
		(void) CFRetain(cf);
	}
	return cf;
}

extern void CFQRelease(CFTypeRef cf)
// See comment in header.
{
	if (cf != NULL) {
		CFRelease(cf);
	}
}

#pragma mark -
#pragma mark ** SC info low level processing **


static void processScInfo(const void *_key,
			const void *_value,
			void *context)
{
	NetworkState *this=(NetworkState *) context;
	NSString *key=(NSString *)_key;
	id pv=(id) _value;
	
	
	NSLog(@"for %@: %@\n", key, pv);
	NSLog(@"for %@, busy=%@ SSID %@, net=%@\n", key, [(id)pv valueForKey:@"Busy"], [(id)pv valueForKey:@"BSSID"], [(id)pv valueForKey:@"SSID_STR"]);
	NSData *bssid=[[[(id)pv valueForKey:@"BSSID"]retain]autorelease];
	NSString *ssidStr=[[[(id)pv valueForKey:@"SSID_STR"]retain]autorelease];
	NSNumber *busy= [(id)pv valueForKey:@"Busy"];
}	
	
static void scCallback(  SCDynamicStoreRef store, 
		       CFArrayRef changedKeys, 
		       void *info)
{
	//NSLog(@"sc callback\n");
	CFDictionaryRef valueDict = SCDynamicStoreCopyMultiple(store,
							       changedKeys,
							       NULL);
	OSStatus err = MoreSCError(valueDict);
	if (err != noErr) return;
	
	CFDictionaryApplyFunction(valueDict,
                                  processScInfo,
                                  NULL);
	CFQRelease(valueDict);
}

#pragma mark -
#pragma mark ** init and callback register **

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
#if 1
	CFStringRef pattern[2];
	pattern[0] = SCDynamicStoreKeyCreateNetworkInterfaceEntity(NULL,
				kSCDynamicStoreDomainState, kSCCompAnyRegex, kSCEntNetAirPort);
        OSStatus err = MoreSCError(pattern);
	if (err != noErr) goto wifi_done;
	
	pattern[1] = SCDynamicStoreKeyCreateNetworkServiceEntity( NULL,
								 kSCDynamicStoreDomainState,  kSCCompAnyRegex, kSCEntNetIPv4);
	err = MoreSCError(pattern);
	if (err != noErr) goto wifi_done;
	
	CFArrayRef patterns = CFArrayCreate(NULL, (const void **) pattern, 2, 
				 &kCFTypeArrayCallBacks);
	err = CFQError(patterns);
	if (err != noErr) goto wifi_done;
	CFDictionaryRef valueDict = SCDynamicStoreCopyMultiple(scdref,
                                               NULL,
                                               patterns);
	err = MoreSCError(pattern);
	if (err != noErr) goto wifi_done;
	
	CFDictionaryApplyFunction(valueDict,
                                  processScInfo,
                                  NULL);
	 

	BOOL ok=SCDynamicStoreSetNotificationKeys(scdref, NULL, patterns);
	CFQRelease(pattern[0]);
	CFQRelease(pattern[1]);
	CFQRelease(patterns);
	CFQRelease(valueDict);

	
#else	
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
#endif
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
