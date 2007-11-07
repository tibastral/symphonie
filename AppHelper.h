//
//  AppHelper.h
//  sipPhone
//
//  Created by Daniel Braun on 26/10/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class sipPhone;

@interface AppHelper : NSObject {
	IBOutlet NSPanel *prefPanel;
	IBOutlet NSWindow *mainWin;
	IBOutlet sipPhone *phone;
	BOOL onDemandRegister;
	BOOL sleepRequested;
	long sleepNotification;
}

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
- (IBAction) goHomePage:(id)sender;

- (IBAction) popMainWin:(id)sender;
@end
