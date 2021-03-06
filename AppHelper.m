//
//  AppHelper.m
//  symPhonie
//
//  Created by Daniel Braun on 26/10/07.
//  Copyright 2007 Daniel Braun. All rights reserved.
//

#import "AppHelper.h"
#import "sipPhone.h"
#import "Properties.h"
#import "BundledScript.h"
#import "PrefPhoneNumberConverter.h"
#import "ABCache.h"
#import <Security/Security.h>
#import <Carbon/Carbon.h>


#include <IOKit/pwr_mgt/IOPMLib.h>
#include <IOKit/IOMessage.h>

#import "UpdateChecker.h"
#import "NetworkState.h"

@implementation AppHelper

static int _debugAudio=0;
static int _debugMisc=0;
static int _debugAuth=0;
static int _debugCauses=0;


#pragma mark -
#pragma mark *** init, dealloc... ***

- (id) init {
	self = [super init];
	if (self != nil) {
		PhoneNumberConverter *pc=[[PrefPhoneNumberConverter alloc]init];
		[pc setIsDefault];
		if (1) NSLog(@"build %s %@ (s:%d.%d.%d)\n", __DATE__, 
			     [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"],
			sizeof(int), sizeof(long), sizeof(void *));
		onDemandRegister=NO; //XXX
		pauseAppScript=[[BundledScript bundledScript:@"sipPhoneAppCtl"]retain];
		if (0) [pauseAppScript runEvent:@"doNothing" withArgs:nil];
		matchPhones=[[NSArray array]retain];
		[self getSipProviders];
	}
	return self;
}
- (void) dealloc 
{
	[netState release];
	[clrMsgTimer0 invalidate];
	[clrMsgTimer0 release];
	[clrMsgTimer1 invalidate];
	[clrMsgTimer1 release];
	[pauseAppScript release];
	[regErrorMsg release];
	[regDiagMsg release];
	[callErrorMsg release];
	[callDiagMsg release];
	[super dealloc];
}

/*
 * lots of init here, mostly registration for network, power status change.
 */

/*
static void networkConnectionCallback( SCNetworkConnectionRef connection, 
				      SCNetworkConnectionStatus status, 
				      void *info);
 */
- (void) awakeFromNib
{
	//[self testSC];

	[[UpdateChecker alloc]init];
	//[upc getUpdateInfos];
	// XXX
	
	NSAssert(phone, @"phone not connected");
	[self defaultProp];
	[self setProvider:nil];
	[prefPanel setLevel:NSModalPanelWindowLevel];
	[audioTestPanel setLevel:NSModalPanelWindowLevel];
	[prefPanel setAlphaValue:0.95];
	
	[self addPowerNotif];
	NSNotificationCenter *notCenter;
	notCenter = [[NSWorkspace sharedWorkspace] notificationCenter];
	[notCenter addObserver:self selector:@selector(_wakeUp:)
			  name:NSWorkspaceSessionDidBecomeActiveNotification object:nil];
	[notCenter addObserver:self selector:@selector(_sessionOut:)
			  name:NSWorkspaceSessionDidResignActiveNotification object:nil];
	[notCenter addObserver:self selector:@selector(_wakeUp:)
			  name:NSWorkspaceDidWakeNotification object:nil];
	//[notCenter addObserver:self selector:@selector(_goSleep:)
	//		  name:NSWorkspaceWillSleepNotification object:nil];
	//[notCenter addObserver:self selector:@selector(_goOff:)
	//		  name:NSWorkspaceWillPowerOffNotification object:nil];
	if (0) [notCenter addObserver:self selector:@selector(_other:)
				 name:nil object:nil];
	if (0) [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(_other2:) 
								       name:nil  object:nil];
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(_soundChanged:) 
								name:@"com.apple.sound.settingsChangedNotification"  object:nil];
	
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(goToFrontRow:) 
								name:@"com.apple.FrontRow.FrontRowWillShow" object:nil];
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(endFrontRow:) 
								name:@"com.apple.FrontRow.FrontRowDidHide" object:nil];
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(ssidChange:) 
								name:@"com.apple.airport.ssid.changed" object:nil];
	
	
	//netState=[[NetworkState alloc]initWithClient:self];
	// now in mib
#if 0

	thisTarget = SCNetworkReachabilityCreateWithName(NULL, "reachabiltyForSymphonie");
	SCNetworkReachabilitySetCallback (thisTarget, reachabilityCallback, &thisContext);
	if (!SCNetworkReachabilityScheduleWithRunLoop(thisTarget,  [[NSRunLoop currentRunLoop]getCFRunLoop], kCFRunLoopDefaultMode)) {
		if (_debugMisc) NSLog (@"Failed to schedule a reacher.");
	}
#endif
	// dial url
	[[NSAppleEventManager sharedAppleEventManager]
	 setEventHandler:self andSelector:@selector(dialFromUrlEvent:withReplyEvent:)
	 forEventClass:kInternetEventClass andEventID:kAEGetURL];	
}

- (void) defaultProp
{
	_debugAudio=getBoolProp(@"debugAudio", NO); 
	_debugMisc=getBoolProp(@"debugMisc", NO);
	_debugAuth=getBoolProp(@"debugAuth", NO);
	_debugCauses=getBoolProp(@"debugCauses", NO);
	[[NSUserDefaultsController sharedUserDefaultsController] setAppliesImmediately:YES];
	getProp(@"phoneNumber",nil);
	getBoolProp(@"setVolume",YES);
	getBoolProp(@"audioRing",YES);
	getBoolProp(@"suspendMultimedia",YES);
	getBoolProp(@"abVisibleOffLineOnStartup",NO);
	[self setOnDemandRegister:getBoolProp(@"onDemandRegister",NO)];
	getBoolProp(@"doubleClickCall",NO);
	//getIntProp(@"provider",1);
	getProp(@"providerName", @"free");
	getBoolProp(@"txboost", YES);
	
	getProp(@"numberRulesPref", [PrefPhoneNumberConverter defaultPrefValue]);
	getProp(@"numberNationalPrefix", @"0");
	getProp(@"numberInternationalPrefix", @"+33");
	getProp(@"numberInternationalPrefix", @"0033");
	getIntProp(@"numberNationalPreference", 0);

	float v1=getFloatProp(@"audioOutputVolume", -8);
	//float v2=getFloatProp(@"audioRingVolume", -8);
	float v3=getFloatProp(@"audioInputGain",-8);
	if (_debugAudio) NSLog(@"volumes are o=%g r=%g i=%g\n", v1, v1, v3);
	
	getProp(@"history", [NSMutableArray arrayWithCapacity:1000]);
	
	getIntProp(@"selectedInputDeviceIndex", 0);
	getIntProp(@"selectedOutputDeviceIndex", 0);

}


- (IBAction) setDefaultNumber:(id)sender
{
	setProp(@"numberRulesPref", [PrefPhoneNumberConverter defaultPrefValue]);
}

#pragma mark -
#pragma mark *** GUI stuffs ***


- (void) openAccountPref
{
	[prefTabView selectTabViewItemWithIdentifier:@"account"];
	[prefPanel makeKeyAndOrderFront:self];
}
- (void)windowDidBecomeMain:(NSNotification *)aNotification
{
	if (!getProp(@"phoneNumber",nil)) {
		[self openAccountPref];
	}
}


#pragma mark -
#pragma mark *** network state, sleep wakeup... ***


- (void) _wakeUp:(NSNotification*)notif 
{
	if (_debugMisc) NSLog(@"wake up\n");
	[phone registerPhone:self];
}

static io_connect_t  root_port;   // a reference to the Root Power Domain IOService

- (void) sleepOk
{
	sleepRequested=NO;
	if (_debugMisc) NSLog(@"sleepok\n");
	IOAllowPowerChange(root_port, sleepNotificationId);
}

- (void) phoneIsOff:(BOOL)unreg
{
	if (_debugMisc) NSLog(@"phone is off (%s)\n", unreg?"unreg":"reg");
	if (!unreg) return;
	if (sleepRequested) [self sleepOk];
	if (exitRequested) {
		if (_debugMisc) NSLog(@"replyToApplicationShouldTerminate\n");
		[[NSApplication sharedApplication] replyToApplicationShouldTerminate:YES];
	}
}

- (void) _sessionOut:(NSNotification*)notif 
{
	if (_debugMisc) NSLog(@"sleeping, notification %@, ui=%@\n", notif, [notif userInfo]);
	switch ([phone state]) {
		case sip_off:
		case sip_ondemand:
			break;
		default:
			[phone unregisterPhone:self];
			//sleepRequested=YES;
			// sleepNotification=....
			break;
	}
	// should call IOAllowPowerChange

}
#if 0
- (void) _goOff:(NSNotification*)notif 
{
	if (_debugMisc) NSLog(@"sleeping\n");
	[phone unregisterPhone:self];
	
}
#endif

- (void) _goSleep:(long)notifId
{
	if (_debugMisc) NSLog(@"sleeping (%lX)", notifId);
	sleepNotificationId=notifId;
	switch ([phone state]) {
		case sip_off:
		case sip_ondemand:
			[self sleepOk];
			break;
		default:
			[phone unregisterPhone:self];
			sleepRequested=YES;
			// sleepNotification=....
			break;
	}
	// should call IOAllowPowerChange
	
}

- (BOOL) canSleep
{
	if ([phone isIdle]) return YES;
	return NO;
}

static void MySleepCallBack( void * refCon, io_service_t service, natural_t messageType, void * messageArgument )
{
	if (_debugMisc) NSLog(@ "messageType %08lx, arg %08lx\n",
	       (long unsigned int)messageType,
	       (long unsigned int)messageArgument );
	AppHelper *me=(AppHelper *) refCon;

	switch ( messageType ) {
		case kIOMessageCanSystemSleep:
			/*
			 Idle sleep is about to kick in.
			 Applications have a chance to prevent sleep by calling IOCancelPowerChange.
			 Most applications should not prevent idle sleep.
			 
			 Power Management waits up to 30 seconds for you to either allow or deny idle sleep.
			 If you don't acknowledge this power change by calling either IOAllowPowerChange
			 or IOCancelPowerChange, the system will wait 30 seconds then go to sleep.
			 */
			if (_debugMisc) NSLog(@"kIOMessageCanSystemSleep\n");
			//IOCancelPowerChange(root_port, (long)messageArgument);
			if ([me canSleep]) {
				// we will allow idle sleep
				IOAllowPowerChange( root_port, (long)messageArgument );
			} else {
				IOCancelPowerChange( root_port, (long)messageArgument );
			}
			break;
			
		case kIOMessageSystemWillSleep:
			/* The system WILL go to sleep. If you do not call IOAllowPowerChange or
			 IOCancelPowerChange to acknowledge this message, sleep will be
			 delayed by 30 seconds.
			 
			 NOTE: If you call IOCancelPowerChange to deny sleep it returns kIOReturnSuccess,
			 however the system WILL still go to sleep.
			 */
			
			// we cannot deny forced sleep
			[me _goSleep:(long)messageArgument];
			
			if (_debugMisc) NSLog(@"kIOMessageSystemWillSleep\n");
			//IOAllowPowerChange( root_port, (long)messageArgument );
			break;
			
			
		default:
			break;
			
	}
}


- (void) addPowerNotif
{
	IONotificationPortRef  notifyPortRef;   // notification port allocated by IORegisterForSystemPower
	io_object_t            notifierObject;  // notifier object, used to deregister later
	
	// register to receive system sleep notifications
	root_port = IORegisterForSystemPower( (void *) self, &notifyPortRef, MySleepCallBack, &notifierObject );
	if (!root_port)
	{
		printf("IORegisterForSystemPower failed\n");
		return;
	}
	
	// add the notification port to the application runloop
	CFRunLoopAddSource( CFRunLoopGetCurrent(),
			   IONotificationPortGetRunLoopSource(notifyPortRef),
			   kCFRunLoopCommonModes );
}

- (void) _other:(NSNotification*)notif 
{
	if (_debugMisc) NSLog(@"got notification %@\n", [notif name]);
}
- (void) _other2:(NSNotification*)notif 
{
	if (_debugMisc) NSLog(@"got notification2 %@\n", [notif name]);
	if ([[notif name]isEqualToString:@"com.apple.ServiceConfigurationChangedNotification"]) {
		if (_debugMisc) NSLog(@"coucou\n");
	}
}
- (void) _soundChanged:(NSNotification*)notif
{
	UserPlane *up=[phone valueForKey:@"userPlane"];
	[up willChangeValueForKey:@"inputDeviceList"];
	[up willChangeValueForKey:@"outputDeviceList"];
	[up didChangeValueForKey:@"inputDeviceList"];
	[up didChangeValueForKey:@"outputDeviceList"];
}


- (void) confChanged:(NSNotification*)notif 
{
	if (_debugMisc) NSLog(@"conf changed %@\n", [notif name]);
}

/*
 * frontrow notification - not yet handled
 * TODO : i dont know exaclty what to do, in-call wont be seen if in frontrow
 * since frontrow can get exclusive audio access, and.. is on the front
 */

- (void) ssidChange: (NSNotification*) notif
{
	NSDictionary *userInfo=[notif userInfo];
	NSLog(@"ssidchange: %@ : ssid:%@\n", [notif name], [userInfo objectForKey:@"SSID_STR"]);

	
}
- (void) goToFrontRow:(NSNotification*)notif 
{
	if (_debugMisc) NSLog(@"going to front row %@\n", [notif name]);
}
- (void) endFrontRow:(NSNotification*)notif 
{
	if (_debugMisc) NSLog(@"ending  front row %@\n", [notif name]);
}

- (void) networkAvailable:(BOOL) av
{
	NSAssert(phone, @"hu");
	networkAvailable=av;
	if (1 || networkAvailable) [phone registerPhone:self];
}
- (void) computerLocationChanged:(NSString *)location
{
	// TODO
}

- (void) quitFromAlertResponse:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	exit(1);
}

/*
 * notification on quit : unregister before quiting
 * this is a bit tricky, because applicationShouldTerminate is invoked
 * from a specific runloop. We HAVE to reply NSTerminateLater
 */
- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	if (_debugMisc) NSLog(@"applicationWillTerminate\n");
}
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	if (_debugMisc) NSLog(@"applicationShouldTerminate\n");
	switch ([phone state]) {
		case sip_off:
		case sip_ondemand:
			return NSTerminateNow;
			break;
		default:
			if (_debugMisc) NSLog(@"terminate later %d\n", [phone state]);
			exitRequested=YES;
			[phone unregisterPhone:self];
			return  NSTerminateLater;
			break;
	}
	return  NSTerminateLater;
}



#pragma mark -
#pragma mark *** url handling (eg from ab plugin) ***
/*
 * dialFromUrlEvent: dial invoqued from sipphone: or tel: url
 * mostly parse the url, invoke a popup, and dial (in dialFromUrlResponse, the popup callback)
 * the number if user is ok
 */
- (void) dialFromUrlResponse:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
	if ((NSAlertFirstButtonReturn == returnCode) || (1==returnCode)) {
		[phone dialOutCall:self];
	}
}

- (void)dialFromUrlEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
	if ([phone state]>sip_registered) return; // already have an active call
	NSString *sUrl = [[ event paramDescriptorForKeyword: keyDirectObject ]
		   stringValue ];
	NSURL *url=[NSURL URLWithString:sUrl];
	if (_debugMisc) NSLog(@"url %@/%@ sheme %@ path %@ host %@ resour %@\n", sUrl, url, [url scheme], [url path], [url host], [url resourceSpecifier]);
// TODO untested with real tel: URI. Furthermore I've almost not read the rfc about tel:uri, thus there are
// chances that is does not work!!!
	NSString *dnum=[url resourceSpecifier];
	NSArray *pn=[dnum componentsSeparatedByString:@";"];
	if (![pn count]) return;
	dnum=[[pn objectAtIndex:0]stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSString *urlName=nil;
	if ([pn count]>=2) {
		urlName=[[pn objectAtIndex:1]stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	}
	
	// look for number in AB. If number is in AB, use AB name value
	// if not, used name value provided in URL, and advised the user
	// that user is unknown
	
	ABCache *abc=[phone abCache];
	NSString *knownName=[[abc findByPhone:dnum] fullName];
	if (knownName) {
		[phone setValue:knownName forKey:@"selectedName"];
	} else {
		if (urlName) knownName=[NSString stringWithFormat:NSLocalizedString(@"UNKNOWN person: %@", @"unknown person"), urlName];
		else knownName=NSLocalizedString(@"unknown person", @"unknown person");
	}
	[phone setValue:dnum forKey:@"selectedNumber"];
	
	if ([phone state]<sip_ondemand) return; // not fully registered
	NSAlert *alert=[NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"dial %@ ?",@"dial popup"),
						      [dnum internationalDisplayCallNumber]]
				       defaultButton:(NSString *)NSLocalizedString(@"OK", @"ok") 
				     alternateButton:(NSString *)NSLocalizedString(@"Cancel", @"cancel")
					 otherButton:(NSString *)nil 
			   informativeTextWithFormat:(NSString *)NSLocalizedString(@"call %@",@"call popup"), knownName];
	
	[alert beginSheetModalForWindow:mainWin
			  modalDelegate:self 
			 didEndSelector:@selector(dialFromUrlResponse:returnCode:contextInfo:)
			    contextInfo:nil];
}


#pragma mark -
#pragma mark *** account handling ***

/*
 * get domain info, free is hardcoded for now
 * 
 */

- (void) getSipProviders
{
	[providers release];
	providers=[[NSMutableDictionary dictionaryWithCapacity:10]retain];
	NSBundle *mb=[NSBundle mainBundle];
	NSArray *f=[mb pathsForResourcesOfType:@".sip.plist" inDirectory:nil];
	int i, count = [f count];
	for (i = 0; i < count; i++) {
		NSString * plist = [f objectAtIndex:i];
		NSLog(@"get %@\n", plist);
		NSError *err;
		NSData *data=[NSData dataWithContentsOfFile:plist options:0 error:&err];
		if (!data) {
			NSLog(@"error reading %@: %@\n", plist, err);
			continue;
		}
		NSString *errstr;
		NSDictionary *prov=[ NSPropertyListSerialization propertyListFromData:data 
							      mutabilityOption:NSPropertyListImmutable 
									format:NULL 
							      errorDescription:&errstr];
		if (!prov) {
			NSLog(@"error parsing %@: %@\n", plist, err);
			continue;
		}
		NSString *n=[prov objectForKey:@"name"];
		if (!n) {
			NSLog(@"no name for %@\n", plist);
			continue;
		}
		[providers setObject:prov forKey:n];
	}
	[providersNames release];
	providersNames=[[providers allKeys]retain];
	// resolve alternate
	count = [providersNames count];
	for (i = 0; i < count; i++) {
		NSString *k = [providersNames objectAtIndex:i];
		NSMutableDictionary *d=[providers objectForKey:k];
		BOOL alt=[[d objectForKey:@"alternateIsAlternate"]boolValue];
		if (!alt) continue;
		NSString *p=[d objectForKey:@"alternateParent"];
		NSDictionary *pi=[providers objectForKey:p];
		if (!pi) continue;
		NSMutableDictionary *m=[pi mutableCopy];
		[m addEntriesFromDictionary:d];
		
		[providers setObject:m forKey:k];
	}
}

- (NSString *) sipFullName
{
	NSString *s=[providerInfo valueForKey:@"providerName"];
	if (!s) s=[providerInfo valueForKey:@"name"];
	return [NSString stringWithFormat:@"%@/%@", s,[self phoneNumber]];
}	
- (NSString *) sipFrom
{
	NSString *p=[self phoneNumber];
	if (!p) return nil;
	NSString *s=[providerInfo valueForKey:@"sipFrom"];
	if (!s) return s;
	return [NSString stringWithFormat:s, p];
	
}
- (NSString *) sipContact
{
	return [self sipFrom];
}

- (NSString *) sipProxy
{
	NSString *s=[providerInfo valueForKey:@"sipProxy"];
	return s;
}
- (NSString *) sipDomain
{
	NSString *s=[providerInfo valueForKey:@"sipDomain"];
	return s;
}

- (NSString *) propNamePhoneNumber
{
	NSString *s=[providerInfo valueForKey:@"providerName"];
	if (!s) s=[providerInfo valueForKey:@"name"];
	if (!s) s=@"dummy";
	return [NSString  stringWithFormat:@"phoneNumber.%@", s];
}
- (NSString *) phoneNumber
{
	return getProp([self propNamePhoneNumber],nil);
}
- (void) setPhoneNumber:(NSString *)s
{
	[self willChangeValueForKey:@"windowTitle"];
	setProp([self propNamePhoneNumber], s);
	[self didChangeValueForKey:@"windowTitle"];
	[phone authInfoChangedWithNetwork:networkAvailable];
}


- (NSString *) provider
{
	NSString *s=getProp(@"providerName", @"free");
	if (_debugMisc) NSLog(@"provider %@\n", s);
	if (![providers objectForKey:s]) {
		s=nil;
	}
	return s;
}

static NSString *GetPasswordKeychain (NSString *account,
				      SecKeychainItemRef *itemRef);
static OSStatus StorePasswordKeychain(NSString *account, NSString* password);

- (BOOL) accountEditable
{
	BOOL alt=[[providerInfo valueForKey:@"alternateIsAlternate"]boolValue];
	if (alt) {
		if (_debugMisc) NSLog(@"accountEditable: NO (alternate)\n");
		return NO;
	}
	BOOL noaccount=[[providerInfo valueForKey:@"noAccountInfo"]boolValue];
	if (noaccount) {
		if (_debugMisc) NSLog(@"accountEditable: NO (noAccountInfo)\n");
		return NO;
	}
	if (_debugMisc) NSLog(@"accountEditable: YES\n");
	return YES;
}
- (void) setProvider:(NSString *)name
{
	if (!name) {
		name=getProp(@"providerName", @"free");
	}
	[phone unregisterPhone:self];
	[self willChangeValueForKey:@"providerTabIdx"];
	[self willChangeValueForKey:@"accountEditable"];
	[self setProviderInfo:[providers objectForKey:name]];
	setProp(@"providerName", name);
	[self didChangeValueForKey:@"providerTabIdx"];
	[self didChangeValueForKey:@"accountEditable"];
	if ([name isEqualToString:@"free"]) {
		//compat: migrate passwd
		NSString *phon=[self phoneNumber];
		if (!phon) {
			phon=getProp(@"phoneNumber", nil);
			if (phon) {
				[self setPhoneNumber:phon];
			}
		}
		NSString *pw=[self password];
		if (!pw) {
			SecKeychainItemRef ir=NULL;
			pw=GetPasswordKeychain([self phoneNumber], &ir);
			if (pw) {
				StorePasswordKeychain([self sipFullName], pw);
			}
		}
	}
	[phone authInfoChangedWithNetwork:networkAvailable];
	
	// ignore and go back to freephonie for now
}



- (void) setProviderInfo:(id)d
{
	if (d != providerInfo) {
		[self willChangeValueForKey:@"accountPhoneLabel"];
		[self willChangeValueForKey:@"passwordHint"];
		[self willChangeValueForKey:@"accountHint"];
		[self willChangeValueForKey:@"phoneNumber"];
		[self willChangeValueForKey:@"password"];
		[self willChangeValueForKey:@"windowTitle"];
		[providerInfo release];
		providerInfo=[d retain];
		[self didChangeValueForKey:@"accountPhoneLabel"];
		[self didChangeValueForKey:@"passwordHint"];
		[self didChangeValueForKey:@"accountHint"];
		[self didChangeValueForKey:@"phoneNumber"];
		[self didChangeValueForKey:@"password"];
		[self didChangeValueForKey:@"windowTitle"];
	}
}
- (id) providerInfo
{
	return providerInfo;
}
- (NSString *) accountPhoneLabel
{
	BOOL isphone=[[providerInfo valueForKey:@"guiAccountIsPhone"]boolValue];
	if (isphone) {
		return NSLocalizedString(@"Phone number:", "Phone number:");
	}
	return NSLocalizedString(@"Account name:", "Account name:");
}

- (NSString *) accountHint
{
	return [providerInfo valueForKey:@"guiAccountHint"];
}
- (NSString *) passwordHint
{
	return [providerInfo valueForKey:@"guiPasswordHint"];
}

	


#pragma mark -
#pragma mark *** keyring handling ***

/*
 * auth info handling. mostly proxy request from user to preferances and keyring
 * and trigger re-registration on any change
 */

- (NSString *) authId
{
	NSString *s=[self phoneNumber];
	if (_debugAuth) NSLog(@"authId:[%@]\n", s);
	return s;
}
- (NSString *) authPasswd
{
	NSString *s=[self password];
	if (_debugAuth) NSLog(@"authPasswd:[%@]\n", s);
	return s;
}


// from apple doc
//Call SecKeychainAddGenericPassword to add a new password to the keychain:
static OSStatus StorePasswordKeychain(NSString *account, NSString* password)
{
	OSStatus status;
	const char *passwordUTF8 = [password UTF8String];
	const char *accountUTF8 = [account UTF8String];
	if (!passwordUTF8 || !passwordUTF8[0]) return 1001;
	if (!accountUTF8 || !accountUTF8[0]) return 1002;
	status = SecKeychainAddGenericPassword (
						NULL,            // default keychain
						9,              // length of service name
						"symPhonie",    // service name
						strlen(accountUTF8),              // length of account name
						accountUTF8,    // account name
						strlen(passwordUTF8),  // length of password
						passwordUTF8,        // pointer to password data
						NULL             // the item reference
						);
	return (status);
}

//Call SecKeychainFindGenericPassword to get a password from the keychain:
static NSString *GetPasswordKeychain (NSString *account,
			      SecKeychainItemRef *itemRef)
{
	OSStatus status1 ;
	const char *accountUTF8 = [account UTF8String];
	if (!accountUTF8) return NULL;
	char *passwd=NULL;
	UInt32 plen=0;

	status1 = SecKeychainFindGenericPassword (
						  NULL,           // default keychain
						  9,             // length of service name
						  "symPhonie",   // service name
						  strlen(accountUTF8),              // length of account name
						  accountUTF8,    // account name
						  &plen,  // length of password
						  (void **) &passwd,   // pointer to password data
						  itemRef         // the item reference
						  );
	if (noErr== status1) {
		passwd[plen]='\0';
		NSString *r=[NSString stringWithUTF8String:passwd];
		SecKeychainItemFreeContent (NULL,           //No attribute data to release
					    passwd    //Release data buffer allocated by
							    //SecKeychainFindGenericPassword
					    );
		return r;
	} else {
		return nil;
	}
}

//Call SecKeychainItemModifyAttributesAndData to change the password for
// an item already in the keychain:
static OSStatus ChangePasswordKeychain (SecKeychainItemRef itemRef, NSString *password)
{
	OSStatus status;
	const char *passwordUTF8 = [password UTF8String];
	//UInt32 plen=(UInt32) strlen(passwordUTF8);
	status = SecKeychainItemModifyAttributesAndData (
							 itemRef,         // the item reference
							 NULL,            // no change to attributes
							 strlen(passwordUTF8),  // length of password
							 passwordUTF8         // pointer to password data
							 );
	return (status);
}


- (void) setPassword:(NSString *)s
{
	OSStatus status;
	//SecKeychainRef kref;
	if (_debugAuth) NSLog(@"set passwd %@\n", s);
	NSString *ph=[self sipFullName];
	if (!ph) return;
	SecKeychainItemRef ir=nil;
	GetPasswordKeychain(ph, &ir);
	if (ir) {
		status=ChangePasswordKeychain(ir, s);
	} else {
		//NSAssert(!ir, @"strange");
		status=StorePasswordKeychain(ph,s);
	}
	if (status != noErr) {
		NSLog(@"store passwd (%s) : error %d\n", ir?"ChangePasswordKeychain":"StorePasswordKeychain", status);
	}
	[phone authInfoChangedWithNetwork:networkAvailable];
	if (onDemandRegister) [phone unregisterPhone:self];
	else [phone registerPhone:self];
}
- (NSString *) password
{
	NSString *ph=[self sipFullName];
	if (!ph) return nil;
	SecKeychainItemRef ir=nil;
	NSString *pw=GetPasswordKeychain(ph, &ir);
	//if (_debugMisc) NSLog(@"got passwd %@\n", pw);

	return pw;
}

// misc stufs

#pragma mark -
#pragma mark *** misc ***

- (BOOL) onDemandRegister;
{
	return onDemandRegister;
}
- (void) setOnDemandRegister:(BOOL)f
{
	if (f != onDemandRegister) {
		onDemandRegister=f;
		if (networkAvailable) {
			if (onDemandRegister) [phone unregisterPhone:self];
			else [phone registerPhone:self];
		}
	}
}

- (BOOL) falseValue
{
	return false;
}


- (IBAction) goHomePage:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString:@"http://braun.daniel.free.fr/symphonie/index.html"]];
}

- (IBAction) popMainWin:(id)sender
{
	[mainWin makeKeyAndOrderFront:self];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
	[mainWin  makeKeyAndOrderFront:self];
	return YES;
}


- (NSString *) windowTitle
{
	if (_debugMisc) NSLog(@"window title\n");
	NSString *k=[providerInfo valueForKey:@"name"];
	if (!k) goto unconfigured;
	NSString *p=[self phoneNumber];
	if (!p) goto unconfigured;
	if ([[providerInfo valueForKey:@"guiAccountIsPhone"]boolValue]) {
		p=[p displayCallNumber];
	}
	return [NSString stringWithFormat:@"%@: %@",k, p];
unconfigured:
	if (k) return [NSString stringWithFormat:@"%@: unconfigured",k];
	return @"unconfigured";
}
- (NSSize)drawerWillResizeContents:(NSDrawer *)sender toSize:(NSSize)contentSize
{
	// quite ugly, but since our drawer is larger than main window
	// which is quite forbiden i guess, we must disallow some resizing
	if (contentSize.width<500) contentSize.width=500;
	return contentSize;
}

- (void)drawerWillOpen:(NSNotification *)notification
{
	NSDrawer *sender=[notification object];
	NSDrawer *other=nil;
	if (sender==drawer1) other=drawer2;
	else if (sender==drawer2) other=drawer1;
	[other close];	
}


#pragma mark -
#pragma mark *** pause audio apps ***


- (void) _pauseApps
{
#if 0
	AppleEvent AE;
	OSErr AECreateAppleEvent(kCoreEventClass, 
				 kAEQuitApplication, 
				 <#const AEAddressDesc * target#>, 
				 <#AEReturnID returnID#>, 
				 <#AETransactionID transactionID#>, 
				 <#AppleEvent * result#>)
#endif
	[pauseAppScript runEvent:@"pauseApp" withArgs:nil];
}

- (void) pauseAppInThread
{
	/* 
	 * yes, normally, applescript can only be launched from main thread
	 * it is safe - at least there is a, hmm, large consensus on that - to call
	 * it from other thread if you do not invoke specific code and do not
	 * use any GUI stuffs (eg dialog)
	 */
	NSAutoreleasePool *mypool=[[NSAutoreleasePool alloc]init];
	if (_debugMisc) NSLog(@"pauseAppInThread/1\n");
	[self _pauseApps];
	if (_debugMisc) NSLog(@"pauseAppInThread/2\n");
	[mypool release];
}

- (void) pauseApps
{
	if (0) {
		[self _pauseApps];
	} else {
		[NSThread detachNewThreadSelector:@selector(pauseAppInThread)
					 toTarget:self withObject:nil];
	}
}
/*
 * audio test stuff
 */

#pragma mark -
#pragma mark *** audio test ***


- (BOOL) audioTestRunning
{
	return audioTestStatus ? YES : NO;
}
- (void) setAudioTestStatus:(int)s
{
	[self willChangeValueForKey:@"audioTestRunning"];
	[self willChangeValueForKey:@"atStatus"];
	audioTestStatus=s;
	[self didChangeValueForKey:@"audioTestRunning"];
	[self didChangeValueForKey:@"atStatus"];
}
- (IBAction) startAudioTest:(id) button
{
	UserPlane *up=[phone valueForKey:@"userPlane"];
	[up startAudioTestWith:self];
	[self setAudioTestStatus:1];

}
- (void) audioTestRecoding
{
	[audioTestPanel makeKeyAndOrderFront:self];
	[self setAudioTestStatus:1];

}
- (void) audioTestPlaying
{
	[self setAudioTestStatus:2];

}
- (void) audioTestEnded
{
	[self setAudioTestStatus:0];
	[audioTestPanel orderOut:self];
}

- (NSString *) atStatus
{
	switch (audioTestStatus) {
		case 0: return @"";
		case 1: return NSLocalizedString(@"Recoding voice, speak!", @"recording started");
		case 2: return NSLocalizedString(@"Playback, listen", @"playback started");
	}
	return @"hu?";
}

#pragma mark -
#pragma mark *** causes handling ***
/*
 * call/registration failures
 */

static NSString *q850(int c)
{
	switch (c) {
		default: return [NSString stringWithFormat:@"Q850/%d", c];
		case 1: return NSLocalizedString(@"unaffected number", @"Q850/1");
		case 2: return NSLocalizedString(@"routing not possible", @"Q850/2");
		case 3: return NSLocalizedString(@"routing not possible", @"Q850/3");
		case 5: return NSLocalizedString(@"incorrect number (bad prefix)", @"Q850/5");
		case 16: return NSLocalizedString(@"normal clearing", @"Q850/16");
		case 17: return NSLocalizedString(@"busy", @"Q850/17");
		case 18: return  NSLocalizedString(@"no reply", @"Q850/18");
		case 19: return  NSLocalizedString(@"no reply", @"Q850/19");
		case 20: return  NSLocalizedString(@"not present", @"Q850/20");
		case 21: return  NSLocalizedString(@"call refused", @"Q850/21");
		case 22: return  NSLocalizedString(@"number has changed", @"Q850/22");
		case 25: return  NSLocalizedString(@"routing error", @"Q850/25");
		case 26: return  NSLocalizedString(@"call cleared", @"Q850/26");
		case 27: return  NSLocalizedString(@"line disturbed", @"Q850/27");
		case 28: return  NSLocalizedString(@"incorrect number", @"Q850/28");
		case 29: return  NSLocalizedString(@"call refused", @"Q850/29");
		case 31: return  NSLocalizedString(@"unspecified failure", @"Q850/31");
		case 34: return  NSLocalizedString(@"no channel", @"Q850/34");
		case 38: return  NSLocalizedString(@"network disturbed", @"Q850/38");
		case 41: return  NSLocalizedString(@"network temporarly disturbed", @"Q850/41");
		case 42: return  NSLocalizedString(@"no channel in network", @"Q850/42");
		case 47: return  NSLocalizedString(@"resource not available", @"Q850/47");
		case 51: return  NSLocalizedString(@"busy", @"Q850/51"); // non standard / used by free at least

		case 57:
		case 58:
		case 49: return  NSLocalizedString(@"QoS not available", @"Q850/49");
		case 50: return  NSLocalizedString(@"service not subscribed", @"Q850/50");
	}
}

- (void) sipError:(int)status_code phrase:(char *)reason_phrase reason:(char *)reason domain:(int)d
{
	NSString *cause=nil;
	NSString *err=nil;
	int cse=0;
	BOOL authErr=NO;

	if (reason) {
		if (!strncmp(reason, "q.850;", 6) || !strncmp(reason, "Q.850;", 6)) {
			char *r=strchr(reason, '=');
			if (r) {
				r++;
				cse=atoi(r);
				cause=q850(cse);
				if (_debugCauses) NSLog(@"Q.850 : (%d) %@\n",cse, cause);
			}
		}
	}
	if (_debugCauses) NSLog(@"====> d=%d st=%d cause %d (%@) / %s\n", d,status_code,
	      cse, 
	      cause ? cause : @"", 
	      reason_phrase ? reason_phrase : "");
	BOOL abnormal=YES;
	if (reason_phrase) cause=[NSString stringWithFormat:@"%d:%s", status_code, reason_phrase];
	else cause=[NSString stringWithFormat:@"%d", status_code];

	switch (status_code) {
		case -2:
			cause=NSLocalizedString(@"Cannot build register (error in config)", @"cannot build reg");
			break;
		//case 401: return;
		//case 407: return;
		case 401: // FALLTHRU
		case 407:
			cause=NSLocalizedString(@"Unauthorized (no password?)", @"unauthorized 401,407");
			break;
		case 0: return;
		case 603:
			if (d) {
				cause=NSLocalizedString(@"Incoming call refuses", "decline 603");
				abnormal=NO;
			}
			break;
		case 487: 
			if (d) {
				if (!cause) cause=NSLocalizedString(@"Call canceled", "terminated 487");
				abnormal=NO;
				break;
			}
			break;
		case 486: 
			if (!cause) cause=NSLocalizedString(@"busy", "@busy 486");
			//abnormal=NO;
			break;
		case 600:
			if (!cause) cause=NSLocalizedString(@"busy", @"busy 600");
			//abnormal=NO;
			break;
		case 403:
			if (21==cse) {
				if (reason_phrase && strcasecmp(reason_phrase, "Too many")) {
					cause=NSLocalizedString(@"already on line",@"303/21");
				}
			} else  if (!cause) {
				cause=NSLocalizedString(@"incorrect password",@"303");
				authErr=YES;
			}
			break;
		case 404:
			if (d && !cause) cause=NSLocalizedString(@"user not found",@"404");
			break;
		case 200:
			abnormal=NO;
			break;
	}
	if (abnormal) {
		if (d) err=NSLocalizedString(@"call failed", @"call failed");
		else  err=NSLocalizedString(@"registration failed", @"registration failed");
	}
	if (cause || err) {
		[self setError:err diag:cause openAccountPref:authErr domain:d];
	}
	
}

- (void) resetErrorForDomain:(int)d
{
	if (!d) {
		[clrMsgTimer0 invalidate];
		[self setRegErrorMsg:nil];
		[self setRegDiagMsg:nil];
	} else {
		[clrMsgTimer1 invalidate];
		[self setCallErrorMsg:nil];
		[self setCallDiagMsg:nil];
	}	
}

- (void) clrTimer0:(NSTimer *)t
{
	[self resetErrorForDomain:0];
}

- (void) clrTimer1:(NSTimer *)t
{
	[self resetErrorForDomain:1];
}

- (void) setError:(NSString *)error diag:(NSString *)diag openAccountPref:(BOOL)gotopref domain:(int)d
{
	if (!d) {
		[self setRegErrorMsg:error];
		[self setRegDiagMsg:diag];
		[clrMsgTimer0 invalidate];
		[clrMsgTimer0 release];
		clrMsgTimer0=[NSTimer timerWithTimeInterval:(NSTimeInterval) (error ? 10 : 4)
					target:self selector:@selector(clrTimer0:) 
				   userInfo:nil repeats:NO];
		[clrMsgTimer0 retain];
		if (clrMsgTimer0) [[NSRunLoop currentRunLoop] addTimer:clrMsgTimer0 forMode:NSDefaultRunLoopMode];
	} else {
		[self setCallErrorMsg:error];
		[self setCallDiagMsg:diag];
		[clrMsgTimer1 invalidate];
		[clrMsgTimer1 release];
		clrMsgTimer1=[NSTimer timerWithTimeInterval:(NSTimeInterval) (error ? 10:4)
				     target:self selector:@selector(clrTimer1:) 
				   userInfo:nil repeats:NO];
		[clrMsgTimer1 retain];
		if (clrMsgTimer1) [[NSRunLoop currentRunLoop] addTimer:clrMsgTimer1 forMode:NSDefaultRunLoopMode];

	}
	if (gotopref) [self openAccountPref];
}


- (void) setRegErrorMsg:(NSString *)str
{
	if (str!=regErrorMsg) {
		[regErrorMsg release];
		regErrorMsg=[str retain];
	}
}
- (NSString *)regErrorMsg
{
	return regErrorMsg;
}

- (void) setRegDiagMsg:(NSString *)str
{
	if (str != regDiagMsg) {
		[regDiagMsg release];
		regDiagMsg=[str retain];
	}
}
- (NSString *)regDiagMsg
{
	return regDiagMsg;
}

//

- (void) setCallErrorMsg:(NSString *)str
{
	if (str!=callErrorMsg) {
		[callErrorMsg release];
		callErrorMsg=[str retain];
	}
}
- (NSString *)callErrorMsg
{
	return callErrorMsg;
}

- (void) setCallDiagMsg:(NSString *)str
{
	if (str != callDiagMsg) {
		[callDiagMsg release];
		callDiagMsg=[str retain];
	}
}
- (NSString *)callDiagMsg
{
	return callDiagMsg;
}

#pragma mark -
#pragma mark *** more goodies ***

- (void)controlTextDidChange:(NSNotification *)aNotification
{
}

- (BOOL)tokenField:(NSTokenField *)tokenField hasMenuForRepresentedObject:(id)representedObjec
{
	return NO;
}

- (NSArray *)tokenField:(NSTokenField *)tokenField completionsForSubstring:(NSString *)substring 
	   indexOfToken:(NSInteger)tokenIndex indexOfSelectedItem:(NSInteger *)selectedIndex
{
	if ([substring length]>26) {
		ABCache *abc=[phone abCache];
		NSArray *ap=[abc allPhones];
		NSMutableArray *app=[NSMutableArray arrayWithCapacity:10];
		int i, count = [ap count];
		NSString *z=[substring internationalCallNumber];
		for (i = 0; i < count; i++) {
			NSString * s = [ap objectAtIndex:i];
			if ([s hasPrefix:z]) {
				[app addObject:[s displayCallNumber]];
			}
		}
		if ([app count]>16) return nil;
		if (![app count]) return nil;
		if (selectedIndex) *selectedIndex=-1;
		return app;
	}
	return nil;
}

- (NSString *)tokenField:(NSTokenField *)tokenField displayStringForRepresentedObject:(id)representedObject
{
	return nil;
}

- (NSMenu *)tokenField:(NSTokenField *)tokenField menuForRepresentedObject:(id)representedObject
{
	return nil;
}

- (void) setMatchPhones:(NSArray *)a
{
	if (a != matchPhones) {
		[self willChangeValueForKey:@"showCompletion"];
		[matchPhones release];
		matchPhones=[a retain];
		[self didChangeValueForKey:@"showCompletion"];
	}
}

- (NSArray *) matchPhones
{
	return matchPhones;
}

#define MAXLIST 32

- (void) updateCompletionList: (NSString *)number
{
	if (!number || ![number length]) {
		[self setMatchPhones:nil];
		return;
	}
	int nmatch=0;
	NSMutableArray *app=[NSMutableArray arrayWithCapacity:MAXLIST];

	NSString *z=[number internationalCallNumber];
	if (![z length]) {
		[self setMatchPhones:nil];
		//return;
		ABAddressBook *ab=[ABAddressBook sharedAddressBook];
		
		ABSearchElement *se1=[ABPerson searchElementForProperty:kABFirstNameProperty/*kABFirstNamePhoneticProperty*/
									label:nil
									  key:nil
									value:number
								   comparison:kABContainsSubStringCaseInsensitive];
		ABSearchElement *se2=[ABPerson searchElementForProperty:kABLastNameProperty
								 label:nil
								   key:nil
								 value:number
							    comparison:kABContainsSubStringCaseInsensitive];
			
		ABSearchElement *se=[ABSearchElement searchElementForConjunction:kABSearchOr
									children:[NSArray arrayWithObjects:se1, se2, nil]];
		//ABSearchElement *se=se2;
		NSArray *ma=[ab recordsMatchingSearchElement:se];
		// assume s is name
		//NSArray *ap=
		//NSLog(@"cound %d\n",[ma count]);
		int i, count = [ma count];
		for (i = 0; i < count; i++) {
			ABPerson * person = [ma objectAtIndex:i];
			ABMultiValue *phones = [person valueForProperty:kABPhoneProperty];
			NSString *fn=[person fullName];
			int j, k;
			k=[phones count];
			for (j=0; j<k; j++) {
				NSString *s=[phones valueAtIndex:j];
				NSString *s2=[s displayCallNumber];
				//if (!s2) s2=s; // useless
				if (!s2) continue;
				[app addObject:[NSDictionary dictionaryWithObjectsAndKeys:
						s2, @"phone",
						fn, @"name",nil]];
				//NSLog(@"got %@\n", s);
				nmatch++;
				if (nmatch>MAXLIST) break;
			}
			
		}
	} else {
		ABCache *abc=[phone abCache];
		NSArray *ap=[abc allPhones];
		int i, count = [ap count];
		
		for (i = 0; i < count; i++) {
			NSString * s = [ap objectAtIndex:i];
			if ([s hasPrefix:z]) {
				NSString *fn=[[abc findByPhone:s]fullName];
				[app addObject:[NSDictionary dictionaryWithObjectsAndKeys:
							       [s displayCallNumber], @"phone",
							       fn, @"name", nil]];
				nmatch++;
				if (nmatch>MAXLIST) break;
				
			}
		}
	}
	if (([app count]>MAXLIST) || (![app count])) {
		[self setMatchPhones:nil];
	}
	[self setMatchPhones:app];
}

- (BOOL) showCompletion
{
	int n=[matchPhones count];
	return ((n>0) && (n<MAXLIST));
}

- (NSIndexSet *) matchPhoneSelect
{
	return [NSIndexSet indexSet];
}
- (void) setMatchPhoneSelect:(NSIndexSet*)si
{
	NSInteger i=[si firstIndex];
	if (NSNotFound==i) return;
	NSDictionary *r=[matchPhones objectAtIndex:i];
	//NSLog(@"select %@\n", r);
	NSAssert([r isKindOfClass:[NSDictionary class]], @"bad class");
	[phone willChangeValueForKey:@"selectedNumber"];
	[phone setSelectedNumber:[r objectForKey:@"phone"] update:NO];
	[phone didChangeValueForKey:@"selectedNumber"];
	//NSLog(@"selected\n");
}

@end
