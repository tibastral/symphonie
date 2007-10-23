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
	sip_off=0,
	sip_register_in_progress,
	sip_register_retry,
	sip_registered,
	sip_outgoing_call_sent,
	sip_outgoing_call_ringing,
	sip_online,
	sip_initiated_clearing,
	sip_incoming_call_ringing
} sipState_t;

@class ABCache;

@interface sipPhone : NSObject {
	sipState_t state;
	int _cid;
	int _did;
	int _tid;
	IBOutlet NSWindow *mainWin;
	IBOutlet NSView *popupInCallView;
	NSWindow *popupInCall;
	IBOutlet ABPeoplePickerView *abPicker;
	// called number
	NSString *selectedNumber;
	NSString *selectedName;
	// caller
	NSString *callingNumber;
	NSString *callingName;
	
	IBOutlet NSTabView *callView;
	BOOL fromAB;
	ABCache *abCache;
	BOOL abVisible;
	BOOL abVisibleOffline;
	NSTimer *pollTimer;
	
	// userplane stuffs
	NSString *localSdp;
	NSString *remoteSdp;
	UserPlane *userPlane;
	
}

- (int) selectedViewNumber;
- (BOOL) abVisible;
- (void) setAbVisible:(BOOL)f;
- (BOOL) isRinging;
- (NSString *) windowTitle;

- (IBAction) testMe:(id) sender;
- (IBAction) pollMe:(id) sender;

- (IBAction) test1:(id) sender;
- (IBAction) test2:(id) sender;

- (void) pollExosip:(NSTimer *)t;
- (void) _initExosip;

- (void) setState:(sipState_t) s;

- (void) setSelectedNumber:(NSString *)s;
- (NSString*) selectedNumber;
- (NSString*) cannonicalSelectedNumber;
- (NSString*) selectedName;
- (void) setSelectedName:(NSString *)s;
- (BOOL) fromAB;
- (void) setFromAB:(BOOL)f;
- (void) setCallingNumber:(NSString *)s;
- (NSString *) callingNumber;
- (NSString *) cannonicalCallingNumber;
- (NSString *) displayCallingNumber;

- (BOOL) incomingCallActive;
- (BOOL) outgoingCallActive;
- (BOOL) onCallActive;

- (IBAction) dialOutCall:(id) sender;
- (IBAction) hangUpCall:(id) sender;
- (IBAction) acceptCall:(id) sender;

@end
