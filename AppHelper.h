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

@interface AppHelper : NSObject <AudioTestHelper> {
	IBOutlet NSPanel *prefPanel;
	IBOutlet NSTabView *prefTabView;
	IBOutlet NSWindow *mainWin;
	IBOutlet SipPhone *phone;
	BOOL onDemandRegister;
	BOOL sleepRequested;
	long sleepNotificationId;
	BOOL exitRequested;
	BundledScript *pauseAppScript;
	BOOL historyVisible;
	int audioTestStatus;
	IBOutlet NSPanel *audioTestPanel;
	BOOL dtmfVisible;
}

- (NSString *) windowTitle;

- (NSString *) authId;
- (NSString *) authPasswd;
- (NSString *) sipFrom;
- (NSString *) sipProxy;
- (NSString *) sipDomain;

- (NSString *) password;
- (void) setPassword:(NSString *)s;

- (int) provider;
- (void) setProvider:(int)tag;

- (BOOL) isFreephonie;

- (NSString *) phoneNumber;
- (void) setPhoneNumber:(NSString *)s;

- (BOOL) falseValue;
- (BOOL) onDemandRegister;
- (void) setOnDemandRegister:(BOOL)f;
- (IBAction) goHomePage:(id)sender;

- (IBAction) popMainWin:(id)sender;

- (void) phoneIsOff:(BOOL)unreg;

- (void) pauseApps;
- (BOOL) audioTestRunning;
- (IBAction) startAudioTest:(id)sender;

- (void) setError:(NSString *)error diag:(NSString *)diag openAccountPref:(BOOL)gotopref;

@end
