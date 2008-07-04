//
//  NetworkState.m
//  sipPhone
//
//  Created by Daniel Braun on 02/07/08.
//  Copyright 2008 Ercom. All rights reserved.
//

#import "NetworkState.h"
#import "Properties.h"

static int _debugSC=NO;
static int _debugHL=NO;

@interface NetworkState()
- (void) _ifaceChanged;
@end


@interface IfaceDescr : NSObject {
	NetworkState *parent; // not retained
	BOOL _isvalid;
	BOOL touched;
	NSArray *addresses;
	BOOL isAirport;
	NSString *ssidStr;
	NSData *bssid;
	BOOL validAirport;
}
- (id) initWithParent:(NetworkState *)p;
- (void) setAddresses:(NSArray *)_addresses;
- (void) setSsid:(NSString *)_s bssid:(NSData *)b busy:(NSNumber *)busy;
- (BOOL) isValid;
- (BOOL) isAirport;
- (NSData *)bssid;
- (NSString *)ssidStr;
@end

@implementation IfaceDescr
- (void) dealloc
{
	[addresses release];
	[ssidStr release];
	[bssid release];
	[super dealloc];
}

- (id) initWithParent:(NetworkState *)p;
{
	self = [super init];
	if (self != nil) {
		parent=p;
	}
	return self;
}
- (BOOL) isValid
{
	if (!touched) return _isvalid;
	BOOL v=YES;
	if (!addresses || ![addresses count]) {
		if (_debugSC) NSLog(@"    ...invalid for no adress\n");
		v=NO;
	} else {
		// check for 169...
		int i, count = [addresses count];
		BOOL hasRealIP=NO;
		for (i = 0; i < count; i++) {
			NSString *a = [addresses objectAtIndex:i];
			if (![a hasPrefix:@"169."] && ![a hasPrefix:@"127."]) hasRealIP=YES;
		}
		if (!hasRealIP) {
			if (_debugSC) NSLog(@"    ...invalid for no real adress\n");
			v=NO;
		}
	}
	if (isAirport && !validAirport) {
		if (_debugSC) NSLog(@"    ...invalid for airport is busy\n");
		v=NO;
	}
	touched=NO;
	_isvalid=v;
	 return _isvalid;
}

- (void) setAddresses:(NSArray *)_addresses
{
	[addresses release];
	addresses=[_addresses retain];
	touched=YES;
	[parent _ifaceChanged];
}
- (void) setSsid:(NSString *)_s bssid:(NSData *)b busy:(NSNumber *)busy
{
	isAirport=YES;
	[ssidStr release];
	ssidStr=[_s retain];
#if 0
	if (!bssid || !b || ![b isEqualToData:bssid]) {
		[addresses release];
		addresses=nil;
	}
#endif
	[bssid release];
	bssid=[b retain];
	BOOL bv=[busy boolValue];
	if (busy && !bv) {
		validAirport=YES;
	} else if (!busy) {
		// consider as non valid if busy flag not present (init state of airport??) ?? finaly no
		validAirport=YES;
	} else {
		validAirport=NO;
	}
	if ([bssid length] != 6) validAirport=NO;
	touched=YES;
	[parent _ifaceChanged];
}
- (BOOL) isAirport
{
	return isAirport;
}

- (NSData *)bssid
{
	return bssid;
}
- (NSString *)ssidStr
{
	return ssidStr;
}



@end




@implementation NetworkState
- (IfaceDescr *) descrFor:(NSString *)name
{
	IfaceDescr *desc=[ifaces objectForKey:name];
	if (!desc) {
		desc=[[IfaceDescr alloc]initWithParent:self];
		[ifaces setObject:desc forKey:name];
		[desc autorelease];
	}
	return desc;
}

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
	NetworkState *ns=(NetworkState *) context;
	NSString *key=(NSString *)_key;
	id pv=(id) _value;
	
	
	if (_debugSC) NSLog(@"for %@: %@\n", key, pv);
	if ([key hasSuffix:(id)kSCEntNetAirPort]) {
		NSArray *ne=[key componentsSeparatedByString:@"/"];
		NSString *iface=[ne objectAtIndex:[ne count]-2];
		IfaceDescr *idesc=[ns descrFor:iface];
		if (_debugSC) NSLog(@"for %@, busy=%@ SSID %@, net=%@\n", iface, [(id)pv valueForKey:@"Busy"], [(id)pv valueForKey:@"BSSID"], [(id)pv valueForKey:@"SSID_STR"]);
		NSData *bssid=[(id)pv valueForKey:@"BSSID"];
		NSString *ssidStr=[(id)pv valueForKey:@"SSID_STR"];
		NSNumber *busy= [(id)pv valueForKey:@"Busy"];
		[idesc setSsid:ssidStr bssid:bssid busy:busy];
	} else if ([key hasSuffix:(id)kSCEntNetIPv4]) {
		NSString *iface=[pv valueForKey:@"InterfaceName"];
		IfaceDescr *idesc=[ns descrFor:iface];
		NSArray *addresses=[pv valueForKey:@"Addresses"];
		[idesc setAddresses:addresses];
	}
}	
	
static void scCallback(  SCDynamicStoreRef store, 
		       CFArrayRef changedKeys, 
		       void *info)
{
	if (_debugSC) NSLog(@"sc callback\n");
	CFDictionaryRef valueDict = SCDynamicStoreCopyMultiple(store,
							       changedKeys,
							       NULL);
	OSStatus err = MoreSCError(valueDict);
	if (err != noErr) return;
	
	CFDictionaryApplyFunction(valueDict,
                                  processScInfo,
                                  info);
	CFQRelease(valueDict);
}

#pragma mark -
#pragma mark ** init and callback register **

- (id) init
{
	_debugSC=getBoolProp(@"debugSC", NO);
	_debugHL=getBoolProp(@"debugHL", NO);
	self = [super init];
	if (self != nil) {
		ifaces=[[NSMutableDictionary dictionaryWithCapacity:10]retain];
	}
	return self;
}

- (void) dealloc
{
	[ifaces release];
	// more to do with sc
	NSAssert(0, @"should not be deallocated");
	[super dealloc];
}

- (void) registerWithSc
{
	NSAssert(client, @"should have client");
	if (scdref) {
		NSLog(@"already registered with sc\n");
		return;
	}
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
                                  (void *)self);
	
	
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
	return;
}

- (void) awakeFromNib
{
	if (client) [self registerWithSc];
}

- (void) setClient:(NSObject  <NetworkStateClient> *) aClient
{
	if (client) {
		[client release];
		client=[aClient retain];
		return;
	}
	client=[aClient retain];
	if (client) [self registerWithSc];
}

- (id) initWithClient:(NSObject  <NetworkStateClient> *) _client
{
	self=[self init];
	[self setClient:_client];
	return self;
}



- (void) ifaceProcessChanges
{
	[self willChangeValueForKey:@"bssid"];
	[self willChangeValueForKey:@"ssidStr"];
	[self willChangeValueForKey:@"interfaceType"];
	[self willChangeValueForKey:@"networkAvailable"];
	changed=NO;
	NSArray *ifs=[ifaces allKeys];
	int i, count = [ifs count];
	NSLog(@"got %d ifaces:\n", count);
	int nvalid=0;
	for (i = 0; i < count; i++) {
		NSString * ifn = [ifs objectAtIndex:i];
		IfaceDescr * ifd = [ifaces objectForKey:ifn];
		BOOL valid=[ifd isValid];
		NSLog(@"    %@: %s\n", ifn, valid ? "OK" :"invalid");
		if (valid) nvalid++;
	}
	BOOL oldreachability=reachability;
	reachability=nvalid ? YES : NO;
	
	if (reachability && !oldreachability) {
		// network now usable
		[client networkAvailable:YES];
	} else if (! reachability && oldreachability) {
		// network no more usable
		[client networkAvailable:NO];
	}
	[self didChangeValueForKey:@"bssid"];
	[self didChangeValueForKey:@"ssidStr"];
	[self didChangeValueForKey:@"interfaceType"];
	[self didChangeValueForKey:@"networkAvailable"];
}
- (void) _ifaceChanged
{
	if (!changed) {
		changed=YES;
		[self performSelectorOnMainThread:@selector(ifaceProcessChanges) withObject:nil waitUntilDone:NO];
	}
}
- (void) registerLocation:(NSString *)name ssid:(NSString *)ssid interface:(NSString *)iface
{
}


- (IfaceDescr *) _mainInterface
{
	// currently simply return the first valid iface
	NSArray *ifn=[ifaces allKeys];
	int i, count = [ifn count];
	for (i = 0; i < count; i++) {
		NSString *n=[ifn objectAtIndex:i];
		IfaceDescr * iface = [ifaces objectForKey:n];
		if ([iface isValid]) return iface;
	}
	return nil;
}
- (NSData *) bssid
{
	IfaceDescr *mi=[self _mainInterface];
	if (!mi) return nil;
	if (![mi isAirport]) return nil;
	NSAssert([mi isValid], @"_mainInterface should only return valid interfaces");
	return [mi bssid];
}

- (NSString *) ssidStr
{
	IfaceDescr *mi=[self _mainInterface];
	if (!mi) return nil;
	if (![mi isAirport]) return nil;
	NSAssert([mi isValid], @"_mainInterface should only return valid interfaces");
	return [mi ssidStr];
}
- (NSString *) interfaceType
{
	IfaceDescr *mi=[self _mainInterface];
	if (!mi) return nil;
	NSAssert([mi isValid], @"_mainInterface should only return valid interfaces");
	if ([mi isAirport]) return @"AirPort";
	return @"Other";
}
- (BOOL) networkAvailable
{
	IfaceDescr *mi=[self _mainInterface];
	if (!mi) return NO;
	return YES;
}

@end
