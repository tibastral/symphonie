//
//  AppHelper.h
//  sipPhone
//
//  Created by Daniel Braun on 26/10/07.
//  Copyright 2007 Daniel Braun. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "UserPlane.h"
@class SipPhone;
@class BundledScript;
@class CallTicketHandler;

/*
 * AppHelper handles most/all of the non-telecom part of the phone.
 * (SipPhone class focuses on telecom stuf, AppHelper on "accessories"
 */ 
 
@interface AppHelper : NSObject <AudioTestHelper> {
	IBOutlet NSPanel *prefPanel;
	IBOutlet NSTabView *prefTabView;
	IBOutlet NSWindow *mainWin;
	IBOutlet SipPhone *phone;
	IBOutlet NSDrawer *drawer1;
	IBOutlet NSDrawer *drawer2;

	
	BOOL onDemandRegister;	// the "receive calls on box"
	
	// handling of power change, application quit events
	BOOL sleepRequested;
	long sleepNotificationId;
	BOOL exitRequested;
	
	// misc
	BundledScript *pauseAppScript;
	BOOL historyVisible;
	int audioTestStatus;
	IBOutlet NSPanel *audioTestPanel;
	BOOL dtmfVisible;
	
	// failure notification messages
	NSString *errorMsg;
	NSString *diagMsg;
}

- (NSString *) windowTitle;	// bound to main window title

// all sip infos
// AppHelper will gather "provider" from preferances, then
// build this info according to e.g. freephonie predefined domain
- (NSString *) authId;
- (NSString *) authPasswd;
- (NSString *) sipFrom;
- (NSString *) sipProxy;
- (NSString *) sipDomain;

- (int) provider;
- (void) setProvider:(int)tag;
- (BOOL) isFreephonie;


// password handling, AppHelper handles keyring storage
// and other preference settinig handling (gui is bound
// to apphelper methods, which in turn will store/read
// in user default, but also do some handling on change
- (NSString *) password;
- (void) setPassword:(NSString *)s;
- (NSString *) phoneNumber;
- (void) setPhoneNumber:(NSString *)s;
- (BOOL) onDemandRegister;
- (void) setOnDemandRegister:(BOOL)f;


- (void) phoneIsOff:(BOOL)unreg;

// audio test (record +play), notifications from UserPlane
// are in AudioTestHelper protocol
- (IBAction) startAudioTest:(id)sender;
- (BOOL) audioTestRunning;


// failure notifications
- (void) setError:(NSString *)error diag:(NSString *)diag openAccountPref:(BOOL)gotopref domain:(int)d;

- (void) setErrorMsg:(NSString *)str;
- (NSString *)errorMsg;

- (void) setDiagMsg:(NSString *)str;
- (NSString *) diagMsg;

// misc
- (IBAction) goHomePage:(id)sender;	// open home page site with eg safari
- (BOOL) falseValue;			// return always false, just a binding facility
- (IBAction) popMainWin:(id)sender;	// open back main window (eg on state change)
- (void) pauseApps;			// launch pause script (pause dvd player, etc..)

- (IBAction) dialPad:(id)sender;

@end
