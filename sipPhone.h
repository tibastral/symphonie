//
//  sipPhone.h
//  sipPhone
//
//  Created by Daniel Braun on 20/10/07.
//  Copyright 2007 Daniel Braun. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AddressBook/AddressBook.h>

#import <AddressBook/ABPeoplePickerView.h>

@class UserPlane;

typedef enum {
	sip_off=0,				//0	
	sip_unregister_in_progress,		//1
	sip_unregister_retry,			//2
	
	sip_register2call_in_progress,		//3
	sip_register2call_retry,		//4

	sip_register_in_progress,		//5
	sip_register_retry,			//6
	
	sip_ondemand,				//7

	sip_registered,				//8
	sip_outgoing_call_sent,			//9
	sip_outgoing_call_ringing,		//10
	sip_online,				//11
	sip_initiated_clearing,			//12
	sip_incoming_call_ringing,		//13
	sip_incoming_call_acccepted,		//14
} sipState_t;

@class ABCache;
@class AppHelper;
@class CallTicketHandler;

@interface SipPhone : NSObject {
	IBOutlet AppHelper *appHelper;
	IBOutlet NSWindow *mainWin;
	IBOutlet NSView *popupInCallView;
	IBOutlet ABPeoplePickerView *abPicker;
	IBOutlet NSTabView *callView;
	IBOutlet CallTicketHandler *tickets;
	
	sipState_t state;
	int _rid;
	int _cid;
	int _did;
	int _tid;
	
	NSWindow *popupInCall;
	NSString *editedPassword;
	// called number
	NSString *selectedNumber;
	NSString *selectedName;
	// caller
	NSString *callingNumber;
	NSString *callingName;
	
	BOOL fromAB;
	ABCache *abCache;
	BOOL abVisible;
	BOOL abVisibleOffline;
	NSTimer *pollTimer;
	NSRunLoop *mainloop;
	// userplane stuffs
	NSString *localSdp;
	NSString *remoteSdp;
	UserPlane *userPlane;
	BOOL audioTest;
}

- (int) selectedViewNumber;
- (BOOL) abVisible;
- (void) setAbVisible:(BOOL)f;
- (BOOL) isRinging;

- (IBAction) dtmf:(id) sender;
- (IBAction) test1:(id) sender;
- (IBAction) test2:(id) sender;

- (void) pollExosip:(NSTimer *)t;
- (void) _initExosip;

- (void) setState:(sipState_t) s;
- (sipState_t) state;

- (void) setSelectedNumber:(NSString *)s;
- (NSString*) selectedNumber;
- (NSString*) internationalSelectedNumber;
- (NSString*) internationalDisplaySelectedNumber;
- (NSString*) selectedName;
- (void) setSelectedName:(NSString *)s;
- (BOOL) fromAB;
- (void) setFromAB:(BOOL)f;
- (void) setCallingNumber:(NSString *)s;
- (NSString *) callingNumber;
- (NSString *) internationalCallingNumber;
- (NSString *) displayCallingNumber;

- (BOOL) incomingCallActive;
- (BOOL) outgoingCallActive;
- (void) makeOutCall;
- (BOOL) isIdle;

- (IBAction) pauseApps:(id) sender;
- (IBAction) ring:(id) sender;
- (IBAction) endRing:(id) sender;

//- (BOOL) onCallActive;
- (BOOL) canChangeRegistrationScheme;
- (BOOL) onLine;
- (IBAction) dialOutCall:(id) sender;
- (IBAction) hangUpCall:(id) sender;
- (IBAction) acceptCall:(id) sender;
- (IBAction) registerPhone:(id) sender;
- (IBAction) unregisterPhone:(id) sender;
- (IBAction) terminateCall:(id) sender;
- (void) authInfoChanged;

- (void) setAudioTest:(BOOL) test;
- (BOOL) audioTest;

- (IBAction) pretendRegistered:(id) sender;
- (IBAction) fakeInCall:(id) sender;

@end
