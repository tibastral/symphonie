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

- (void) _goSleep:(NSNotification*)notif 
{
	NSLog(@"sleeping\n");
	[phone unregisterPhone:self];

}
- (void) _goOff:(NSNotification*)notif 
{
	NSLog(@"sleeping\n");
	[phone unregisterPhone:self];
	
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
	
	NSNotificationCenter *notCenter;
	notCenter = [[NSWorkspace sharedWorkspace] notificationCenter];
	[notCenter addObserver:self selector:@selector(_wakeUp:)
			  name:NSWorkspaceSessionDidBecomeActiveNotification object:nil];
	[notCenter addObserver:self selector:@selector(_goSleep:)
			  name:NSWorkspaceSessionDidResignActiveNotification object:nil];
	[notCenter addObserver:self selector:@selector(_wakeUp:)
			  name:NSWorkspaceDidWakeNotification object:nil];
	[notCenter addObserver:self selector:@selector(_goSleep:)
			  name:NSWorkspaceWillSleepNotification object:nil];
	[notCenter addObserver:self selector:@selector(_goOff:)
			  name:NSWorkspaceWillPowerOffNotification object:nil];
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
	UInt32 plen=(UInt32) strlen(passwordUTF8);
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
@end
