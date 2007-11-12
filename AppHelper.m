//
//  AppHelper.m
//  sipPhone
//
//  Created by Daniel Braun on 26/10/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "AppHelper.h"
#import "sipPhone.h"
#import "Properties.h"
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
	}
	return self;
}
- (void) dealloc {
	
	[super dealloc];
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

- (void) phoneIsOff
{
	if (sleepRequested) [self sleepOk];
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
	[prefPanel setLevel:NSModalPanelWindowLevel];
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
	setProp(@"phoneNumber",s);
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


@end
