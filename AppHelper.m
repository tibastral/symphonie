//
//  AppHelper.m
//  sipPhone
//
//  Created by Daniel Braun on 26/10/07.
//  Copyright 2007 Daniel Braun. All rights reserved.
//

#import "AppHelper.h"
#import "sipPhone.h"
#import "Properties.h"
#import "BundledScript.h"
#import "StringCallNumber.h"
#import "ABCache.h"
#import <Security/Security.h>

#include <CoreFoundation/CoreFoundation.h>
#include <SystemConfiguration/SystemConfiguration.h>
#import <Carbon/Carbon.h>


#include <IOKit/pwr_mgt/IOPMLib.h>
#include <IOKit/IOMessage.h>

@implementation AppHelper

static int _debugAudio=0;
static int _debugMisc=0;
static int _debugAuth=0;

- (id) init {
	self = [super init];
	if (self != nil) {
		PhoneNumberConverter *pc=[[PhoneNumberConverter alloc]init];
		[pc setIsDefault];
		if (1) NSLog(@"build %s\n", __DATE__);
		onDemandRegister=NO; //XXX
		pauseAppScript=[[BundledScript bundledScript:@"sipPhoneAppCtl"]retain];
		[pauseAppScript runEvent:@"doNothing" withArgs:nil];
	}
	return self;
}
- (void) dealloc 
{
	[pauseAppScript release];

	[super dealloc];
}

- (void) defaultProp
{
	_debugAudio=getBoolProp(@"debugAudio", NO);
	_debugMisc=getBoolProp(@"debugMisc", NO);
	_debugAuth=getBoolProp(@"debugAuth", NO);
	[[NSUserDefaultsController sharedUserDefaultsController] setAppliesImmediately:YES];
	getProp(@"phoneNumber",nil);
	getBoolProp(@"setVolume",YES);
	getBoolProp(@"audioRing",YES);
	getBoolProp(@"suspendMultimedia",YES);
	getBoolProp(@"abVisibleOnStartup",YES);
	[self setOnDemandRegister:getBoolProp(@"onDemandRegister",NO)];
	getBoolProp(@"doubleClickCall",NO);
	getIntProp(@"provider",1);


	float v1=getFloatProp(@"audioOutputVolume", -8);
	float v2=getFloatProp(@"audioRingVolume", -8);
	float v3=getFloatProp(@"audioInputGain",-8);
	if (_debugAudio) NSLog(@"volumes are o=%g r=%g i=%g\n", v1, v2, v3);
	
	getProp(@"history", [NSMutableArray arrayWithCapacity:1000]);
	
	getIntProp(@"selectedInputDeviceIndex", 0);
	getIntProp(@"selectedOutputDeviceIndex", 0);

}

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

- (void) goToFrontRow:(NSNotification*)notif 
{
	if (_debugMisc) NSLog(@"going to front row %@\n", [notif name]);
}
- (void) endFrontRow:(NSNotification*)notif 
{
	if (_debugMisc) NSLog(@"ending  front row %@\n", [notif name]);
}


static void PrintReachabilityFlags(
				   const char *                hostname, 
				   SCNetworkConnectionFlags    flags, 
				   const char *                comment
				   )
// Prints a line that records a reachability transition. 
// This includes the current time, the new state of the 
// reachability flags (from the flags parameter), and the 
// name of the host (from the hostname parameter).
{
	time_t      now;
	struct tm   nowLocal;
	char        nowLocalStr[30];
	
	assert(hostname != NULL);
	
	if (comment == NULL) {
		comment = "";
	}
	
	(void) time(&now);
	(void) localtime_r(&now, &nowLocal);
	(void) strftime(nowLocalStr, sizeof(nowLocalStr), "%X", &nowLocal);
	
	fprintf(stdout, "%s %c%c%c%c%c%c%c %s%s\n",
		nowLocalStr,
		(flags & kSCNetworkFlagsTransientConnection)  ? 't' : '-',
		(flags & kSCNetworkFlagsReachable)            ? 'r' : '-',
		(flags & kSCNetworkFlagsConnectionRequired)   ? 'c' : '-',
		(flags & kSCNetworkFlagsConnectionAutomatic)  ? 'C' : '-',
		(flags & kSCNetworkFlagsInterventionRequired) ? 'i' : '-',
		(flags & kSCNetworkFlagsIsLocalAddress)       ? 'l' : '-',
		(flags & kSCNetworkFlagsIsDirect)             ? 'd' : '-',
		hostname,
		comment
		);
}

- (void) reachable
{
	NSAssert(phone, @"hu");
	//SCNetworkProtocolGetConfiguration(<#SCNetworkProtocolRef protocol#>)
	[phone registerPhone:self];
}

/*
 * dialFromUrlEvent: dial invoqued from sipphone: or tel: url
 * mostly parse the url, invoke a popup, and dial (in dialFromUrlResponse, the popup callback)
 * the number if user is ok
 */
- (void) dialFromUrlResponse:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
	if ((NSAlertFirstButtonReturn == returnCode) || (1==returnCode)) {
		[phone makeOutCall];
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
	
	ABCache *abc=[phone valueForKey:@"abCache"];
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
				       defaultButton:(NSString *)NSLocalizedString(@"OK", "ok") 
				     alternateButton:(NSString *)NSLocalizedString(@"Cancel", "cancel")
					 otherButton:(NSString *)nil 
			   informativeTextWithFormat:(NSString *)NSLocalizedString(@"call %@",@"call popup"), knownName];
	
	[alert beginSheetModalForWindow:mainWin
			  modalDelegate:self 
			 didEndSelector:@selector(dialFromUrlResponse:returnCode:contextInfo:)
			    contextInfo:nil];
}

/* network change callback
 * we actually dont check reachability but try to register at
 * any network change - and this appears to be very fine
 */
static void reachabilityCallback(SCNetworkReachabilityRef	target,
				   SCNetworkConnectionFlags	flags,
				   void *                      info)
{
	if (_debugMisc) NSLog(@"callbacked\n");
	PrintReachabilityFlags(" for freephonie.net", flags, "");
	AppHelper *s=(AppHelper *)info;
	[s reachable];
}

/*
 * lots of init here, mostly registration for network, power status change.
 */

- (void) awakeFromNib
{
	NSAssert(phone, @"phone not connected");
	[self defaultProp];
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
	SCNetworkReachabilityRef        thisTarget;
	SCNetworkReachabilityContext    thisContext;
	thisContext.version         = 0;
	thisContext.info            = (void *) self;
	thisContext.retain          = NULL;
	thisContext.release         = NULL;
	thisContext.copyDescription = NULL;
	
	thisTarget = SCNetworkReachabilityCreateWithName(NULL, "freephonie.net");
	SCNetworkReachabilitySetCallback (thisTarget, reachabilityCallback, &thisContext);
	if (!SCNetworkReachabilityScheduleWithRunLoop(thisTarget,  [[NSRunLoop currentRunLoop]getCFRunLoop], kCFRunLoopDefaultMode)) {
		if (_debugMisc) NSLog (@"Failed to schedule a reacher.");
	}
	[[NSAppleEventManager sharedAppleEventManager]
		setEventHandler:self andSelector:@selector(dialFromUrlEvent:withReplyEvent:)
		forEventClass:kInternetEventClass andEventID:kAEGetURL];	
}

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


/*
 * get domain info, free is hardcoded for now
 * TODO: user provider to find these info
 */

- (NSString *) sipFrom
{
	int provider=[self provider];
	switch (provider) {
		default:
		case 1: 
			return [NSString stringWithFormat:@"sip:%@@freephonie.net",[self phoneNumber]]; 
			break;
		case 99: // test
			return [NSString stringWithFormat:@"sip:%@@localhost",[self phoneNumber]]; 
			break;
	}
}
- (NSString *) sipProxy
{
	int provider=[self provider];
	switch (provider) {
		default:
		case 1: 
			return @"sip:freephonie.net";
		case 99:
			return @"sip:localhost";
	}
			
}
- (NSString *) sipDomain
{
	int provider=[self provider];
	switch (provider) {
		default:
		case 1: 
			return @"freephonie.net";
		case 99:
			return @"localhost";
	}
}

// from apple doc
//Call SecKeychainAddGenericPassword to add a new password to the keychain:
static OSStatus StorePasswordKeychain(NSString *account, NSString* password)
{
	OSStatus status;
	const char *passwordUTF8 = [password UTF8String];
	const char *accountUTF8 = [account UTF8String];

	status = SecKeychainAddGenericPassword (
						NULL,            // default keychain
						8,              // length of service name
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
	char *passwd=NULL;
	UInt32 plen=0;

	status1 = SecKeychainFindGenericPassword (
						  NULL,           // default keychain
						  8,             // length of service name
						  "symPhonie",   // service name
						  strlen(accountUTF8),              // length of account name
						  accountUTF8,    // account name
						  &plen,  // length of password
						  (void **) &passwd,   // pointer to password data
						  itemRef         // the item reference
						  );
	if (noErr== status1) {
		passwd[plen]='\0';
		NSString *r=[NSString stringWithCString:passwd encoding:NSUTF8StringEncoding];
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
	NSString *ph=[self phoneNumber];
	if (!ph) return;
	SecKeychainItemRef ir=nil;
	GetPasswordKeychain(ph, &ir);
	if (ir) {
		status=ChangePasswordKeychain(ir, s);
	} else {
		//NSAssert(!ir, @"strange");
		status=StorePasswordKeychain(ph,s);
	}
	[phone authInfoChanged];
	if (onDemandRegister) [phone unregisterPhone:self];
	else [phone registerPhone:self];
}
- (NSString *) password
{
	NSString *ph=[self phoneNumber];
	if (!ph) return nil;
	SecKeychainItemRef ir=nil;
	NSString *pw=GetPasswordKeychain(ph, &ir);
	//if (_debugMisc) NSLog(@"got passwd %@\n", pw);

	return pw;
}
- (NSString *) phoneNumber
{
	return getProp(@"phoneNumber",nil);
}
- (void) setPhoneNumber:(NSString *)s
{
	[self willChangeValueForKey:@"windowTitle"];
	setProp(@"phoneNumber",s);
	[self didChangeValueForKey:@"windowTitle"];
	[phone authInfoChanged];
}


- (int) provider
{
	int prov=getIntProp(@"provider",1);
	if (_debugMisc) NSLog(@"provider %d\n", prov);
	return prov;
}

- (void) setProvider:(int)tag
{
	[self willChangeValueForKey:@"isFreephonie"];
	setProp(@"provider", [NSNumber numberWithInt:tag]);
	[self didChangeValueForKey:@"isFreephonie"];
	[phone authInfoChanged];

	// ignore and go back to freephonie for now
}

- (BOOL) isFreephonie
{
	return ([self provider]==1);
}

// misc stufs

- (BOOL) onDemandRegister;
{
	return onDemandRegister;
}
- (void) setOnDemandRegister:(BOOL)f
{
	if (f != onDemandRegister) {
		onDemandRegister=f;
		if (onDemandRegister) [phone unregisterPhone:self];
		else [phone registerPhone:self];
	}
}

- (BOOL) falseValue
{
	return false;
}


- (IBAction) goHomePage:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString:@"http://braun.daniel.free.fr/page3/sipPhone/sipPhone.shtml"]];
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
			if (_debugMisc) NSLog(@"terminate later\n");
			exitRequested=YES;
			[phone unregisterPhone:self];
			return  NSTerminateLater;
			break;
	}
	return  NSTerminateLater;
}

/*
 * misc stuff
 */

- (NSString *) windowTitle
{
	if (_debugMisc) NSLog(@"window title\n");
	return [NSString stringWithFormat:@"symPhonie (%@)", [[self phoneNumber]displayCallNumber]];
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
	NSDrawer *other;
	if (sender==drawer1) other=drawer2;
	else if (sender==drawer2) other=drawer1;
	[other close];	
}


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

/*
 * call/registration failures
 * TODO
 */
- (void) setError:(NSString *)error diag:(NSString *)diag openAccountPref:(BOOL)gotopref domain:(int)d
{
	[self setErrorMsg:error];
	[self setDiagMsg:diag];
	if (gotopref) [self openAccountPref];
}


- (void) setErrorMsg:(NSString *)str
{
	if (str!=errorMsg) {
		[errorMsg release];
		errorMsg=[str retain];
	}
}
- (NSString *)errorMsg
{
	return errorMsg;
}

- (void) setDiagMsg:(NSString *)str
{
	if (str != diagMsg) {
		[diagMsg release];
		diagMsg=[str retain];
	}
}
- (NSString *)diagMsg
{
	return diagMsg;
}

- (IBAction) dialPad:(id)sender
{
	int tag=[sender tag];
	NSLog(@"dialpad %d\n", tag);

}

@end
