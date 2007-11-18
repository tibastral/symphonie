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

- (id) init {
	self = [super init];
	if (self != nil) {
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
	NSLog(@"volumes are o=%g r=%g i=%g\n", v1, v2, v3);
	
	getProp(@"history", [NSMutableArray arrayWithCapacity:1000]);
	
	getIntProp(@"selectedInputDeviceIndex", 0);
	getIntProp(@"selectedOutputDeviceIndex", 0);

}

- (void)windowDidBecomeMain:(NSNotification *)aNotification
{
	if (!getProp(@"phoneNumber",nil)) {
		[prefPanel makeKeyAndOrderFront:self];
	}
}

- (void) _wakeUp:(NSNotification*)notif 
{
	NSLog(@"wake up\n");
	[phone registerPhone:self];
}

static io_connect_t  root_port;   // a reference to the Root Power Domain IOService

- (void) sleepOk
{
	NSLog(@"sleepok\n");
	IOAllowPowerChange(root_port, sleepNotificationId);
}

- (void) phoneIsOff:(BOOL)unreg
{
	NSLog(@"phone is off (%s)\n", unreg?"unreg":"reg");
	if (!unreg) return;
	if (sleepRequested) [self sleepOk];
	else if (exitRequested) {
		NSLog(@"replyToApplicationShouldTerminate\n");
		[[NSApplication sharedApplication] replyToApplicationShouldTerminate:YES];
	}
}

- (void) _sessionOut:(NSNotification*)notif 
{
	NSLog(@"sleeping, notification %@, ui=%@\n", notif, [notif userInfo]);
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
	NSLog(@"sleeping\n");
	[phone unregisterPhone:self];
	
}
#endif

- (void) _goSleep:(long)notifId
{
	NSLog(@"sleeping (%lX)", notifId);
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
	NSLog(@ "messageType %08lx, arg %08lx\n",
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
			NSLog(@"kIOMessageCanSystemSleep\n");
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
			
			NSLog(@"kIOMessageSystemWillSleep\n");
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
	NSLog(@"got notification %@\n", [notif name]);
}
- (void) _other2:(NSNotification*)notif 
{
	NSLog(@"got notification2 %@\n", [notif name]);
	if ([[notif name]isEqualToString:@"com.apple.ServiceConfigurationChangedNotification"]) {
		NSLog(@"coucou\n");
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
	NSLog(@"conf changed %@\n", [notif name]);
}


- (void) goToFrontRow:(NSNotification*)notif 
{
	NSLog(@"going to front row %@\n", [notif name]);
}
- (void) endFrontRow:(NSNotification*)notif 
{
	NSLog(@"ending  front row %@\n", [notif name]);
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
- (void) dialFromUrlResponse:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
	if ((NSAlertFirstButtonReturn == returnCode) || (1==returnCode)) {
		[phone makeOutCall];
	}
}

- (void)dialFromUrlEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
	if (![phone isIdle]) return;
	NSString *sUrl = [[ event paramDescriptorForKeyword: keyDirectObject ]
		   stringValue ];
	NSURL *url=[NSURL URLWithString:sUrl];
	NSLog(@"url %@/%@ sheme %@ path %@ host %@ resour %@\n", sUrl, url, [url scheme], [url path], [url host], [url resourceSpecifier]);
	/* TODO popup for confirm */
	NSString *dnum=[url resourceSpecifier];
	NSArray *pn=[dnum componentsSeparatedByString:@";"];
	if (![pn count]) return;
	dnum=[[pn objectAtIndex:0]stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSString *urlName=nil;
	if ([pn count]>=2) {
		urlName=[[pn objectAtIndex:1]stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	}
	ABCache *abc=[phone valueForKey:@"abCache"];
	NSString *knownName=[[abc findByPhone:dnum] fullName];
	if (knownName) {
		[phone setValue:knownName forKey:@"selectedName"];
	} else {
		if (urlName) knownName=[NSString stringWithFormat:NSLocalizedString(@"UNKNOWN person: %@", @"unknown person"), urlName];
		else knownName=NSLocalizedString(@"unknown person", @"unknown person");
	}
	[phone setValue:dnum forKey:@"selectedNumber"];
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

static void reachabilityCallback(SCNetworkReachabilityRef	target,
				   SCNetworkConnectionFlags	flags,
				   void *                      info)
{
	NSLog(@"callbacked\n");
	PrintReachabilityFlags(" for freephonie.net", flags, "");
	AppHelper *s=(AppHelper *)info;
	[s reachable];
}

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
		NSLog (@"Failed to schedule a reacher.");
	}
	[[NSAppleEventManager sharedAppleEventManager]
		setEventHandler:self andSelector:@selector(dialFromUrlEvent:withReplyEvent:)
		forEventClass:kInternetEventClass andEventID:kAEGetURL];	
}


- (NSString *) authId
{
	return [self phoneNumber];
}
- (NSString *) authPasswd
{
	return [self password];
}

- (NSString *) sipFrom
{
	return [NSString stringWithFormat:@"sip:%@@freephonie.net",[self phoneNumber]]; 
}
- (NSString *) sipProxy
{
	return @"sip:freephonie.net";
}
- (NSString *) sipDomain
{
	return @"freephonie.net";
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
						"sipPhone",    // service name
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
						  "sipPhone",   // service name
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
	NSLog(@"set passwd %@\n", s);
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
	[phone registerPhone:self];
}
- (NSString *) password
{
	NSString *ph=[self phoneNumber];
	if (!ph) return nil;
	SecKeychainItemRef ir=nil;
	NSString *pw=GetPasswordKeychain(ph, &ir);
	//NSLog(@"got passwd %@\n", pw);

	return pw;
}
	

- (int) provider
{
	return 1;
}

- (void) setProvider:(int)tag
{
	// ignore and go back to freephonie for now
}

- (BOOL) isFreephonie
{
	return YES;
}

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
- (NSString *) phoneNumber
{
	return getProp(@"phoneNumber",nil);
}
- (void) setPhoneNumber:(NSString *)s
{
	[self willChangeValueForKey:@"windowTitle"];
	setProp(@"phoneNumber",s);
	[self didChangeValueForKey:@"windowTitle"];
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
	//pauseAppScript=[BundledScript bundledScript:@"sipPhoneAppCtl"];
	[pauseAppScript runEvent:@"pauseApp" withArgs:nil];
}

- (void) pauseAppInThread
{
	NSAutoreleasePool *mypool=[[NSAutoreleasePool alloc]init];
	NSLog(@"pauseAppInThread/1\n");
	[self _pauseApps];
	NSLog(@"pauseAppInThread/2\n");
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


- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	NSLog(@"applicationWillTerminate\n");
}
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	NSLog(@"applicationShouldTerminate\n");
	switch ([phone state]) {
		case sip_off:
		case sip_ondemand:
			return NSTerminateNow;
			break;
		default:
			NSLog(@"terminate later\n");
			exitRequested=YES;
			[phone unregisterPhone:self];
			return  NSTerminateLater;
			break;
	}
	return  NSTerminateLater;
}

- (NSString *) windowTitle
{
	NSLog(@"window title\n");
	return [NSString stringWithFormat:@"sipPhone (%@)", [[self phoneNumber]displayCallNumber]];
}
- (NSSize)drawerWillResizeContents:(NSDrawer *)sender toSize:(NSSize)contentSize
{
	if (contentSize.width<500) contentSize.width=500;
	return contentSize;
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


@end
