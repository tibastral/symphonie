//
//  sipPhone.h
//  symPhonie
//
//  Created by Daniel Braun on 20/10/07.
//  Copyright 2007 Daniel Braun. All rights reserved
//

#import <Cocoa/Cocoa.h>
#import <AddressBook/AddressBook.h>

#import <AddressBook/ABPeoplePickerView.h>

@class UserPlane;

/*
 * sipState_t, our finate state machine states
 * obviously we handle here two differents things: the registration
 * state and the call state. SIP mix both in an unpleasant way (eg
 * compared to GMM/SM GPRS/3G) 
 * We target only single call phone, though it is safe for now
 * to keep a single fsm, though we may evolve to 2 separate fsm
 */

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


/*
 * SipPhone: main telecom class: the global finate state machine
 * every telecom stuf (except SDP handling which is un UserPlane)
 * is handled here. And everything that is not telecom is typically
 * moved to AppHelper (though there are still some non telecom stuff here)
 */

@interface SipPhone : NSObject {
	IBOutlet AppHelper *appHelper;
	
	sipState_t state;
	int _rid;
	int _cid;
	int _did;
	int _tid;
	NSTimer *pollTimer;
	
	NSString *serviceRoute;
	// called number (out call), and its AB name
	NSString *selectedNumber;
	NSString *selectedName;
	// caller (in call)
	NSString *callingNumber;
	NSString *callingName;
	
	
	// userplane stuffs
	NSString *localSdp;
	NSString *remoteSdp;
	UserPlane *userPlane;
	BOOL audioTest;		// should be moved to AppHelper
	NSDate *callDate;
	int pollcount;
	int maxDuration;
	
	IBOutlet NSWindow *mainWin;
	IBOutlet NSView *popupInCallView;
	IBOutlet ABPeoplePickerView *abPicker;
	IBOutlet CallTicketHandler *tickets;
	NSWindow *popupInCall;
	IBOutlet NSTextField *numberTextView;
	IBOutlet NSButton *callbutton;
	IBOutlet NSView *offlineView;
	
	BOOL fromAB;	// true if selectedNumber comes from AddressBook (and has not been changed)
	ABCache *abCache;
	BOOL abVisible;		// bound to ABPeoplePickerView drawer visibility
	BOOL abVisibleOffline;  // remind picker visibility when in "offline" state
}


- (ABCache *)abCache;

- (void) setState:(sipState_t) s;
- (sipState_t) state;

- (int) selectedViewNumber;	// bound to tabview - selects the current view (unreg, offline,...)
- (IBAction) abDClicked:(id)sender;
- (IBAction) historyDClicked:(id)sender;
- (IBAction) completionDClicked:(id)sender;


// some flags, usable in bindings, that depends on state
- (BOOL) isRinging;
- (BOOL) canChangeRegistrationScheme;
- (BOOL) onLine;

// called / calling number, usable in bindings, with different formats
- (void) setSelectedNumber:(NSString *)s;
- (void) setSelectedNumber:(NSString *)s update:(BOOL)upd;
- (NSString*) selectedNumber;
- (NSString*) internationalSelectedNumber;
- (NSString*) internationalDisplaySelectedNumber;
- (NSString*) selectedName;
- (void) setSelectedName:(NSString *)s;
- (void) setCallingNumber:(NSString *)s;
- (NSString *) callingNumber;
- (NSString *) internationalCallingNumber;
- (NSString *) displayCallingNumber;

- (BOOL) fromAB;
- (void) setFromAB:(BOOL)f;
- (BOOL) abVisible;		// bound to AB picker view drawer
- (void) setAbVisible:(BOOL)f;


//- (IBAction) dtmf:(id) sender;
- (IBAction) test1:(id) sender;
- (IBAction) test2:(id) sender;

- (void) pollExosip:(NSTimer *)t;
- (int) _initExosip;

- (BOOL) incomingCallActive;
- (BOOL) outgoingCallActive;
- (void) makeOutCall;
- (BOOL) isIdle;

- (IBAction) pauseApps:(id) sender;
- (IBAction) ring:(id) sender;
- (IBAction) endRing:(id) sender;

//- (BOOL) onCallActive;

- (IBAction) dialOutCall:(id) sender;
- (IBAction) hangUpCall:(id) sender;
- (IBAction) acceptCall:(id) sender;
- (IBAction) registerPhone:(id) sender;
- (IBAction) unregisterPhone:(id) sender;
- (IBAction) terminateCall:(id) sender;


- (void) authInfoChangedWithNetwork:(BOOL)net; // invoked by AppHelper when user/passwd had been changed,
						// thus sipPhone shall re-register

- (void) setAudioTest:(BOOL) test;
- (BOOL) audioTest;

- (IBAction) dialPad:(id)sender;

- (int) callDuration;
- (NSString *) callDurationTxt;
- (int) maxDuration;
- (void) setMaxDuration:(int)v;

// used for debug only
- (IBAction) pretendRegistered:(id) sender;
- (IBAction) fakeInCall:(id) sender;

@end
