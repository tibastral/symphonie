//
//  sipPhone.m
//  sipPhone
//
//  Created by Daniel Braun on 20/10/07.
//  Copyright 2007 Daniel Braun. All rights reserved.
//

#import "sipPhone.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include "eXosip2/eXosip.h"

#import "StringCallNumber.h"

#import "UserPlane.h"
#import "ABCache.h"
#import "AppHelper.h"
#import "Properties.h"
#import "CallTicketHandler.h"


//#import <Foundation/NSRunLoop.h>
#import <AddressBook/AddressBook.h>

static int lastlock=0;
static int lastunlock=0;
#define EXOSIP_LOCK() do { eXosip_lock(); lastlock=__LINE__; } while(0)
#define EXOSIP_UNLOCK() do { eXosip_unlock();lastunlock= __LINE__; } while(0)

int _debugFsm=0;
int _debugAudio=0;
int _debugMisc=0;
int _debugCauses=0;

static NSString *
eXosip_get_sdp_body (osip_message_t * message)
{
	osip_content_type_t *ctt;
	osip_mime_version_t *mv;
	osip_body_t *oldbody;
	int pos;
	
	if (message == NULL) return nil;
	
	/* get content-type info */
	ctt = osip_message_get_content_type (message);
	mv = osip_message_get_mime_version (message);
	if (mv == NULL && ctt == NULL) {
		return nil;                /* previous message was not correct or empty */
	}
	if (mv != NULL) {
		/* look for the SDP body */
		/* ... */
	} else if (ctt != NULL)	{
		if (ctt->type == NULL || ctt->subtype == NULL) {
			/* it can be application/sdp or mime... */
			return nil;
		}
		if (osip_strcasecmp (ctt->type, "application") != 0 ||
		    osip_strcasecmp (ctt->subtype, "sdp") != 0) {
			return nil;
		}
	}
	
	pos = 0;
	NSString *res=nil;
	while (!osip_list_eol (message->bodies, pos)) {		
		oldbody = (osip_body_t *) osip_list_get (message->bodies, pos);
		pos++;
		if (!res) res=[NSString stringWithCString:oldbody->body];
		else res=[res stringByAppendingString:
			[NSString stringWithCString:oldbody->body]];
	}
	return res;
}

@implementation SipPhone

static int initDone=0;

- (id) init {
	self = [super init];
	if (self != nil) {
		userPlane=[[UserPlane alloc]init];
		abCache=[[ABCache alloc]init];
		abVisibleOffline=YES;
		[self setState:sip_off];
	}
	return self;
}
- (void) dealloc {
	[ABCache release];
	[selectedNumber release];
	[selectedName release];
	[callingNumber release];
	[pollTimer invalidate];
	[pollTimer release];
	[userPlane endUserPlane];
	[userPlane release];
	[localSdp release];
	[remoteSdp release];
	[super dealloc];
}

/*
 * ============== AdressBook interaction ===============
 */


- (void)recordChange:(NSNotification*)notif {
	//NSImage *personImage;
	NSString *personName;
	NSArray *array;
	
	array = [abPicker selectedRecords];
	NSArray *a2=[abPicker selectedValues];
	if (!array && !a2) return;
	ABPerson *person;

	if (![array count]) person=nil;
	else person = [array objectAtIndex:0];
	
	if (![a2 count]) {
		[self setSelectedNumber:nil];
	} else {
		[self setSelectedNumber:[a2 objectAtIndex:0]];
	}
	// personImage = [[NSImage alloc] initWithData:[person imageData]];
	NSString *n1=[person valueForProperty:kABFirstNameProperty];
	NSString *n2=[person valueForProperty:kABLastNameProperty];
	if (!n2) personName=n1;
	else if (!n1) personName=n2;
	else personName  = [NSString stringWithFormat:@"%@ %@",n1,n2];
	[self setSelectedName:personName];
	[self setFromAB:YES];
	
	//[imageView setImage:personImage];
	//[nameField setStringValue:personName];
	
	//[personImage release];
}

- (IBAction) abDClicked:(id)this
{
	NSLog(@"double click\n");
	if (getBoolProp(@"doubleClickCall",NO)) {
		[self dialOutCall:self];
	}
}

- (void) awakeFromNib
{
	_debugFsm=getBoolProp(@"debugFsm", NO);
	_debugAudio=getBoolProp(@"debugAudio", NO);
	_debugMisc=getBoolProp(@"debugMisc", NO);
	_debugCauses=getBoolProp(@"debugCauses", NO);

	abVisibleOffline=getBoolProp(@"abVisibleOnStartup",YES);
	if ([appHelper onDemandRegister]) [self setState:sip_ondemand];
	NSAssert(abPicker, @"unconnected abPicker");
	//[abPicker clearSearchField:self];

	//NSView *v=[abPicker accessoryView];
	//[abPicker setAllowsMultipleSelection:NO];
	//[abPicker setAllowsEmptySelection:YES];
	[abPicker deselectAll:nil];
	//ABPickerDeselectAll(abPicker);
#if 0
	NSArray *cursel=[abPicker selectedGroups];
	unsigned int i, count = [cursel count];
	for (i = 0; i < count; i++) {
		ABRecord * obj = (ABGroup *)[cursel objectAtIndex:i];
		[abPicker deselectGroup:obj];
	}
#endif
	
	
	//[abPicker setValueSelectionBehavior:ABSingleValueSelection];
	[abPicker setTarget:self];
	[abPicker setNameDoubleAction:@selector(abDClicked:)];
	//Here we set up a responder for one of the four notifications,
	//in this case to tell us when the selection in the name list
	//has changed.
	NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
	if (0) [center addObserver:self
		   selector:@selector(recordChange:)
		       name:ABPeoplePickerNameSelectionDidChangeNotification
		     object:abPicker];
	[center addObserver:self
		   selector:@selector(recordChange:)
		       name:ABPeoplePickerValueSelectionDidChangeNotification
		     object:abPicker];
	
	//[abPicker deselectSelectedCell];

	[self _initExosip];
	
	popupInCall = [[NSWindow alloc] initWithContentRect:[popupInCallView frame]
						  styleMask:NSBorderlessWindowMask
						    backing:NSBackingStoreBuffered defer:YES];
	//[popupInCall setBackgroundColor:[NSColor blackColor]];
	[popupInCall setExcludedFromWindowsMenu:YES];
	[popupInCall setLevel:NSScreenSaverWindowLevel];
	[popupInCall setShowsToolbarButton:NO];
	[popupInCall setAlphaValue:0.55];
	[popupInCall setOpaque:NO];
	[popupInCall setHasShadow:NO];
	[popupInCall setMovableByWindowBackground:YES];
	[popupInCall center];
	[popupInCall setContentView:popupInCallView];
	
}

- (void) setSelectedNumber:(NSString *)s
{
	if (selectedNumber != s) {
		[self willChangeValueForKey:@"internationalSelectedNumber"];
		[self willChangeValueForKey:@"internationalDisplaySelectedNumber"];
		[selectedNumber release];
		selectedNumber=[s retain];
		[self setFromAB:NO];
		[self didChangeValueForKey:@"internationalDisplaySelectedNumber"];
		[self didChangeValueForKey:@"internationalSelectedNumber"];

	}
}
- (NSString*) selectedNumber
{
	return selectedNumber;
}
- (NSString*) internationalSelectedNumber
{
	return [selectedNumber internationalCallNumber];
}
- (NSString*) internationalDisplaySelectedNumber
{
	return [selectedNumber internationalDisplayCallNumber];
}

- (NSString*) selectedName
{
	return selectedName;
}

- (void) setSelectedName:(NSString *)s
{
	if (s != selectedName) {
		[selectedName release];
		selectedName=[s retain];
	}
}
- (NSString*) callingName
{
	return callingName;
}

- (void) setCallingName:(NSString *)s
{
	if (s != callingName) {
		[callingName release];
		callingName=[s retain];
	}
}

- (NSString *) displayCallingNumber
{
	return [callingNumber internationalDisplayCallNumber];
}


- (void) setCallingNumber:(NSString *)s
{
	if (s!=callingNumber) {
		[self willChangeValueForKey:@"internationalCallingNumber"];
		[self willChangeValueForKey:@"displayCallingNumber"];

		[callingNumber release];
		callingNumber=[s retain];
		ABPerson *caller=[abCache findByPhone:callingNumber];
		NSString *n1=[caller valueForProperty:kABFirstNameProperty];
		NSString *n2=[caller valueForProperty:kABLastNameProperty];
		NSString *personName;
		if (!n2) personName=n1;
		else if (!n1) personName=n2;
		else personName  = [NSString stringWithFormat:@"%@ %@",n1,n2];
		[self setCallingName:personName];
		
		[self didChangeValueForKey:@"displayCallingNumber"];
		[self didChangeValueForKey:@"internationalCallingNumber"];

	}
}
- (NSString*) internationalCallingNumber
{
	return [callingNumber internationalCallNumber];
}
- (NSString *) callingNumber
{
	return [callingNumber internationalDisplayCallNumber];
}

- (BOOL) fromAB
{
	return fromAB;
}
- (void) setFromAB:(BOOL)f
{
	if (fromAB != f) {
		fromAB=f;
		if (!fromAB) [self setSelectedName:@""];
	}
}
/*
 * ============== phone itself ===============
 */
- (int) selectedViewNumber
{
	switch (state) {
		case sip_off: return 0;
		case sip_ondemand: return 1;
		case sip_register_in_progress: return 0;
		case sip_register_retry: return 0;
		case sip_register2call_in_progress: return 2;
		case sip_register2call_retry: return 2;
		case sip_unregister_in_progress: return 0;
		case sip_unregister_retry: return 0;
		case sip_registered: return 1;
		case sip_outgoing_call_sent: return 2;
		case sip_outgoing_call_ringing: return 2;
		case sip_online: return 3;
		case sip_initiated_clearing: return 4;
		case sip_incoming_call_ringing: return 5;
		case sip_incoming_call_acccepted: return 3;
		default: return 1;
	}
}


- (BOOL) abVisible
{
	return abVisible;
}
- (void) setAbVisible:(BOOL)f
{
	//if (f && !abVisible) 	[abPicker deselectAll:self];
	if ((sip_registered==state)||(sip_ondemand==state)) abVisibleOffline=f;
	abVisible=f;
}
- (BOOL) isRinging
{
	return (state==sip_outgoing_call_ringing);
}
- (BOOL) isIdle
{
	switch (state) {
		case sip_off: 
		case sip_ondemand:
		case sip_registered:
			return YES;
		default: break;
	}
	return NO;
}


- (sipState_t) state
{
	return state;
}
- (void) setState:(sipState_t) s
{
	sipState_t olds;
	if (_debugFsm) NSLog(@"== state %d->%d\n", state,s);

	if (state==s) return;
	// some hook when leaving a state
	olds=state;
	if (state==sip_incoming_call_ringing) {
		[popupInCall orderOut:self];
		[userPlane stopRing];
	}
	[self willChangeValueForKey:@"incomingCallActive"];
	[self willChangeValueForKey:@"outgoingCallActive"];
	[self willChangeValueForKey:@"onLine"];
	[self willChangeValueForKey:@"selectedViewNumber"];
	[self willChangeValueForKey:@"isRinging"];
	[self willChangeValueForKey:@"canChangeRegistrationScheme"];
	state=s;
	if ((olds==sip_registered) || (olds==sip_ondemand)) [self setAbVisible:NO];
	if ((state==sip_registered)  || (state==sip_ondemand)) [self setAbVisible:abVisibleOffline];
	if (1 || (state==sip_incoming_call_ringing)) {
		[mainWin makeKeyAndOrderFront:self];
	}
	if (state==sip_incoming_call_ringing) {
		if (getBoolProp(@"popupRing",  YES))	    [popupInCall makeKeyAndOrderFront:self];
		if (getBoolProp(@"suspendMultimedia", YES)) [appHelper pauseApps];
		if (getBoolProp(@"audioRing",  YES))	    [userPlane startRing];
	}
	if ((state==sip_online) && (olds != sip_incoming_call_ringing)) {
		if (getBoolProp(@"suspendMultimedia", YES)) [appHelper pauseApps];
	}
	if (state==sip_off) {
		[appHelper phoneIsOff:YES];
	}
	[self didChangeValueForKey:@"canChangeRegistrationScheme"];
	[self didChangeValueForKey:@"isRinging"];
	[self didChangeValueForKey:@"selectedViewNumber"];
	[self didChangeValueForKey:@"incomingCallActive"];
	[self didChangeValueForKey:@"outgoingCallActive"];
	[self didChangeValueForKey:@"onLine"];
	
}


- (BOOL) incomingCallActive
{ 
	switch (state) {
		default:
			return NO;
			break;
	}
	return NO;
}
- (BOOL) outgoingCallActive
{
	switch (state) {
		case sip_registered:
		case sip_ondemand:
			return YES;
		default: break;
	}
	return NO;
}

- (BOOL) onLine;
{
	switch (state) {
		case sip_online: return YES;
		default: 
			break;
	}
	return NO;
}

- (BOOL) canChangeRegistrationScheme
{
	if (state==sip_ondemand) return YES;
	if (state==sip_registered) return YES;
	return NO;
}

- (void) _initExosip
{
	int rc;
	if (initDone) return;
	TRACE_INITIALIZE (6, stdout);
	
	rc=eXosip_init();
	if (rc!=0) return;
	
	rc = eXosip_listen_addr (IPPROTO_UDP, NULL, 5060, AF_INET, 0);
	if (rc!=0)
	{
		eXosip_quit();
		NSAssert(0, @"init failed\n");
		fprintf (stderr, "could not initialize transport layer\n");
		return;
	}
	initDone=1;
	// from quit, have a different runloop
	// mainloop=[NSRunLoop currentRunLoop];//not retained
#if 0
	pollTimer=[NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)0.1 
					  target:self selector:@selector(pollExosip:) userInfo:nil repeats:YES];
#else
	pollTimer=[NSTimer timerWithTimeInterval:(NSTimeInterval)0.1 
						   target:self selector:@selector(pollExosip:) userInfo:nil repeats:YES];
	[pollTimer retain];
	[[NSRunLoop currentRunLoop] addTimer:pollTimer forMode:NSDefaultRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer:pollTimer forMode:NSModalPanelRunLoopMode];

#endif
}


- (void) authInfoChanged
{
	eXosip_clear_authentication_info();
	eXosip_add_authentication_info([[appHelper authId]cString], [[appHelper authId]cString], [[appHelper authPasswd]cString],
			       NULL, NULL);
}

- (IBAction) registerPhoneOnDemand:(BOOL) onDemand dur:(int)dur;
{
	osip_message_t *reg = NULL;
	int rc;
	
	//NSAssert(state==sip_off, @"bad state for registerPhone");
	EXOSIP_LOCK ();
	_rid = eXosip_register_build_initial_register ([[appHelper sipFrom]cString], [[appHelper sipProxy]cString], [[appHelper sipFrom]cString],
						     dur, &reg);
	if (_rid < 0)
	{
		EXOSIP_UNLOCK ();
		//NSAssert(0, @"registered failed\n");
		NSLog(@"register failed (buid initial reg) %d", _rid);
		return;
	}
	//NSLog(@"password %@\n",[appHelper authPasswd]);
	eXosip_clear_authentication_info();
	eXosip_add_authentication_info([[appHelper authId]cString], [[appHelper authId]cString], [[appHelper authPasswd]cString],
					    NULL, NULL);
	
	if (0) osip_message_set_supported (reg, "100rel");
	if (0) osip_message_set_supported(reg, "path");
	
	rc = eXosip_register_send_register (_rid, reg);
	EXOSIP_UNLOCK ();
	NSAssert(!rc, @"eXosip_register_send_register failed\n");
	if (dur) {
		if (onDemand) {
			[self setState:sip_register2call_in_progress];
		} else {
			[self setState:sip_register_in_progress];
		}
	} else {
		[self setState:sip_unregister_in_progress];
	}
	return;
}
- (IBAction) registerPhone:(id) sender
{
	if ([appHelper onDemandRegister]) {
		if (state<sip_ondemand) [self setState:sip_ondemand];
		return;
	}
	[self registerPhoneOnDemand:NO dur:1800];
}

- (IBAction) unregisterPhone:(id) sender;
{
	osip_message_t *reg = NULL;
	int rc;
	if (state < sip_registered) {
		[self registerPhoneOnDemand:NO dur:0];
		return;
	}
	[self hangUpCall:sender];
	//NSAssert(state==sip_off, @"bad state for registerPhone");
	EXOSIP_LOCK ();
	// TODO should use initial register ?
	rc = eXosip_register_build_register(_rid, 0 /* expire 0= unregister*/, &reg);
	if (rc < 0)
	{
		EXOSIP_UNLOCK ();
		//NSAssert(0, @"registered failed\n");
		NSLog(@"unregister failed (build) rc=%d, _rid=%d\n", rc);
		return;
	}
	
	rc = eXosip_register_send_register (_rid, reg);
	EXOSIP_UNLOCK ();
	NSAssert(!rc, @"eXosip_register_send_register failed\n");
	[self setState:sip_unregister_in_progress];
#if 0
	NSRunLoop *curloop=[NSRunLoop currentRunLoop];
	if (0 && (curloop != mainloop)) {
		NSLog(@"new loop, restart timer\n");
		[pollTimer invalidate];
		[pollTimer release];
		pollTimer=[NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)0.1 
							   target:self selector:@selector(pollExosip:) userInfo:nil repeats:YES];
	}
#endif
	return;
}


- (IBAction) pretendRegistered:(id) sender
{
	if (state<sip_registered) [self setState:sip_registered];
}

/*
 * the main finate state machine - most of the phone is here
 * exosip is called by polling - polling at 10Hz - more than enough for sip-
 * cost nothing in cpu and is much more simpler/safer than any other
 * mechanism - specifically
 * not knowing the internal of exosip 
 */
- (void) pollExosip:(NSTimer *)t
{
	eXosip_event_t *je;
	int rc;
		
	static BOOL inpoll=NO;
	// check we are not re-entered - indeed we are not, but if an exception occurs
	// (in this case we brutaly leave pollExosip letting the inpoll flag to yes
	if (0) NSAssert(!inpoll, @"reentered");
	inpoll=YES;

	for (;;) {
		je = eXosip_event_wait (0, 0);
		EXOSIP_LOCK();
		eXosip_automatic_action ();
		EXOSIP_UNLOCK();
		if (je == NULL) break;
		if (_debugFsm) NSLog(@"event %d (%s) tid %d cid %d rid %d did %d\n", je->type, je->textinfo, je->tid, je->cid, je->rid, je->did);
		if (je->rid) { 
			
			// handle registration events
			// --------------------------
			
			// TODO check rid is current rid
			int status_code;
			switch (je->type) {
				case EXOSIP_REGISTRATION_FAILURE:
					if (je->response) NSLog(@"got status: %d / %s\n", je->response->status_code, 
					      je->response->reason_phrase);
					status_code=je->response ? je->response->status_code : 0;
					if (403 /*TODO this is not only wrong password*/==status_code) {
						[self setState:sip_off];
						[appHelper setError:NSLocalizedString(@"Registration failed", @"Registration failed")
							     diag:NSLocalizedString(@"Wrong Password", @"Wrong Password")
						    openAccountPref:YES
							     domain:0];
						rc=eXosip_default_action(je);
						break;
					} else if (!je->response) {
						[appHelper setError:NSLocalizedString(@"Registration failed", @"Registration failed")
							       diag:NSLocalizedString(@"no reply", @"no reply")
						    openAccountPref:NO
							     domain:0];
					}
					switch (state) {
						case sip_register_retry:
							[self setState:sip_off];
							break;
						case sip_register_in_progress:
							[self setState:sip_register_retry];
							rc=eXosip_default_action(je);
							if (rc) {
								//[self setState:sip_off];
								break;
							}
							break;
						case sip_register2call_retry:
							[self setState:sip_ondemand];
							break;
						case sip_register2call_in_progress:
							[self setState:sip_register2call_retry];
							rc=eXosip_default_action(je);
							if (rc && (401!=status_code)) {
								[self setState:sip_ondemand];
								break;
							}
							break;
						case sip_unregister_retry:
							[self setState:sip_off];
							break;
						case sip_unregister_in_progress:
							[self setState:sip_unregister_retry];
							rc=eXosip_default_action(je);
							if (rc && (401!=status_code)) {
								[self setState:sip_off];
								break;
							}
							break;
						default:
							break;
					}
					break;
				case EXOSIP_REGISTRATION_SUCCESS:
					if (_debugFsm) NSLog(@"registration ok\n");
					switch (state) {
						case sip_off:
						case sip_register_retry:
						case sip_register_in_progress:
							[self setState:sip_registered];
							if (_debugFsm) NSLog(@"now registered\n");
							break;
						case sip_register2call_retry:
						case sip_register2call_in_progress:
							[self setState:sip_registered];
							if (_debugFsm) NSLog(@"now registered, mazke call\n");
							[self makeOutCall];
							break;
						case sip_unregister_in_progress:
						case sip_unregister_retry:
							if (_debugFsm) NSLog(@"now deregistered\n");
							if ([appHelper onDemandRegister]) {
								[self setState:sip_ondemand];
							} else {
								[self setState:sip_off];
							}
							break;
						default:
							if (_debugFsm) NSLog(@"registered ignore in state %d\n", state);
							break;
					}
					break;
				default:
					rc=eXosip_default_action(je);
					break;
			}
		} else if (je->cid) {
			// handle call events
			// ------------------
			if (je->response) {
				osip_header_t *hdr;
				int s=je->response->headers ? osip_list_size(je->response->headers):0;
				int i;
				for (i=0; i<s; i++) {
					hdr=(osip_header_t *)osip_list_get(je->response->headers, i);
					if (!strcmp(hdr->hname, "reason")) {
						if (_debugCauses) NSLog(@"XXX got reason %s\n", hdr->hvalue);
					}
				}
			} 
			if (je->request) {
				osip_header_t *hdr;
				int s=je->request->headers ? osip_list_size(je->request->headers):0;
				int i;
				for (i=0; i<s; i++) {
					hdr=(osip_header_t *)osip_list_get(je->request->headers, i);
					if (!strcmp(hdr->hname, "reason")) {
						if (_debugCauses) NSLog(@"XXX (req) got reason %s\n", hdr->hvalue);
					}
				}
			}
			if (_cid != je->cid) {
				if (je->type==EXOSIP_CALL_INVITE) {
					if (_debugFsm) NSLog(@"incoming new call\n");
					if (!je->request) goto refuse_call;
					if (!je->request->from) goto refuse_call;
					char *f=je->request->from->displayname;
					if (!f) goto refuse_call;
					[self setCallingNumber:[NSString stringWithCString:f]];
					
					_cid=je->cid;
					_did=je->did;
					_tid=je->tid;
					[self willChangeValueForKey:@"remoteSdp"];
					[remoteSdp release];
					remoteSdp=[eXosip_get_sdp_body(je->request) retain];
					[self didChangeValueForKey:@"remoteSdp"];
					[self willChangeValueForKey:@"localSdp"];
					[localSdp release];
					localSdp=[[userPlane setupAndGetLocalSdp]retain];
					NSString *nlsdp=nil;
					BOOL ok=[userPlane setupWithtLocalSdp:localSdp remoteSdp:remoteSdp outCall:NO negociatedLocal:&nlsdp];
					if (!ok) {
						[self didChangeValueForKey:@"localSdp"];
						[self hangUpCall:self];
						break;
					}				
					[localSdp release];
					localSdp=[nlsdp retain];
					[self didChangeValueForKey:@"localSdp"];
					osip_message_t *answer=NULL;
					eXosip_call_build_answer(_tid, 180, &answer);
					osip_message_set_body (answer, [localSdp cString], [localSdp length]);
					osip_message_set_content_type (answer, "application/sdp");
					EXOSIP_LOCK ();
					eXosip_call_send_answer (je->tid, 180, answer);
					EXOSIP_UNLOCK ();
					[self setState:sip_incoming_call_ringing];

					break;
refuse_call:
					EXOSIP_LOCK ();
					eXosip_call_send_answer (je->tid, 415, NULL);
					EXOSIP_UNLOCK ();
					
				}
				rc=eXosip_default_action(je);
				eXosip_event_free(je);
				continue;
			}
			
			switch (je->type) {
				case EXOSIP_CALL_REINVITE:
					if (_debugFsm) NSLog(@"reinvinte (call within a call)\n");
					rc=eXosip_default_action(je);
					break;
				case EXOSIP_CALL_INVITE:if (_debugFsm) NSLog(@"incoming call on existing call?\n");
					EXOSIP_LOCK ();
					eXosip_call_send_answer (je->tid, 415, NULL);
					EXOSIP_UNLOCK ();
					break;
				case EXOSIP_CALL_PROCEEDING:
					break;
				case EXOSIP_CALL_RINGING:
					[self setState:sip_outgoing_call_ringing];
					if (je->did) _did=je->did;
						break;
				case EXOSIP_CALL_REQUESTFAILURE:
					if (_debugFsm) NSLog(@"EXOSIP_CALL_REQUESTFAILURE %d / %s\n",
					      je->response ?  je->response->status_code : -1,
					      je->response ? je->response->reason_phrase : "?");					
					if (je->response != NULL) {
						BOOL keepcall=NO;
						
						switch (je->response->status_code) {
							case 403:
								[appHelper setError:NSLocalizedString(@"Call failed", @"Call failed")
									       diag:NSLocalizedString(@"Wrong Password", @"Wrong Password")
								    openAccountPref:YES
									     domain:1];
								break;
							case 401:
							case 407:
								rc=eXosip_default_action(je);
								keepcall=YES;
								break;
							case 487:
								// user cancel
								break;
							case 486:
								// intern serv error
								if (_debugFsm) NSLog(@"486 here\n");
								break;
							default:
								break;
						}
						if (keepcall) break;

					}
					
					[userPlane endUserPlane];
					rc=eXosip_default_action(je);
					if (state>sip_registered) [self terminateCall:self];
					rc=eXosip_default_action(je);
					break;
				case EXOSIP_CALL_SERVERFAILURE:
					NSLog(@"EXOSIP_CALL_SERVERFAILURE\n");
					break;
				case EXOSIP_CALL_GLOBALFAILURE:
					NSLog(@"EXOSIP_CALL_GLOBALFAILURE\n");
					break;
				case EXOSIP_CALL_ANSWERED:
					if (_debugFsm) NSLog(@"call answered\n");
					if (je->did) _did=je->did;
						
#if 0
						if (je->response) {
							remote_sdp = eXosip_get_sdp_info (je->response);
						}
							if (!remote_sdp) {
								[self cancelCall];
								break;
							}
							conn = eXosip_get_audio_connection (remote_sdp);
					remote_med = eXosip_get_audio_media (remote_sdp);
#endif
					[self willChangeValueForKey:@"remoteSdp"];
					[remoteSdp release];
					remoteSdp=[eXosip_get_sdp_body(je->response) retain];
					[self didChangeValueForKey:@"remoteSdp"];
					
					BOOL ok=[userPlane setupWithtLocalSdp:localSdp remoteSdp:remoteSdp outCall:YES negociatedLocal:nil];
					if (!ok) NSLog(@"userplane setup problem\n");
					//[self establishUserPlaneLocal:&local_med remote:&remote_med];
					
					osip_message_t *ack;
					rc = eXosip_call_build_ack(je->did, &ack);
					if (rc != 0) {
						NSLog(@"eXosip_call_build_ack failed...\n");
						break;
					}
					EXOSIP_LOCK();
					eXosip_call_send_ack(je->did, ack);
					//eXosip_call_terminate (je->cid, je->tid);
					EXOSIP_UNLOCK();
					[self setState:sip_online];
					break;
				case EXOSIP_CALL_MESSAGE_NEW:
					if (_debugFsm) NSLog(@"msg new (EXOSIP_CALL_MESSAGE_NEW)\n");
					break;
				case EXOSIP_CALL_MESSAGE_PROCEEDING:
					if (_debugFsm) NSLog(@"call proceed\n");
					if (je->did) _did=je->did;
						break;
				case EXOSIP_CALL_RELEASED:
					[userPlane endUserPlane];
					rc=eXosip_default_action(je);
					if (state>sip_registered) [self terminateCall:self];
					if (_debugFsm) NSLog(@"call released (EXOSIP_CALL_RELEASED)\n");
					break;
				case EXOSIP_CALL_CLOSED:
					[userPlane endUserPlane];
					rc=eXosip_default_action(je);
					if (state>sip_registered) [self terminateCall:self]; // XXX
					if (_debugFsm) NSLog(@"call released (EXOSIP_CALL_CLOSED)\n");
					break;
				case EXOSIP_CALL_ACK:
					if (state==sip_incoming_call_acccepted) {
						[self setState:sip_online];
					}
				default:
					if (_debugFsm) NSLog(@"not handled event %d (%s)\n", je->type, je->textinfo);
					break;
			}
		} else {
			
			rc=eXosip_default_action(je);
		}
		
		eXosip_event_free(je);
	}
	inpoll=NO;
}

- (void) makeOutCall
{
	NSAssert(sip_registered==state, @"bad state for ocall");
	
	osip_message_t *invite = NULL;
	
	int rc;
	rc = eXosip_call_build_initial_invite(&invite,
						  [[NSString stringWithFormat:@"sip:%@@%@", [self internationalSelectedNumber], [appHelper sipDomain]]cString],
						 [[appHelper sipFrom]cString],
						 NULL,
						 "phone call");
	if (rc) return;
	osip_message_set_supported (invite, "100rel");
	//if (_debugFsm) NSLog(@"invite tid %d cid %d\n", invite->tid, invite->cid);
	[userPlane endUserPlane];
	
	[self willChangeValueForKey:@"localSdp"];
	[localSdp release];
	localSdp=[[userPlane setupAndGetLocalSdp] retain];
	[self didChangeValueForKey:@"localSdp"];

	osip_message_set_body (invite, [localSdp cString], [localSdp length]);
	osip_message_set_content_type (invite, "application/sdp");
	
	
	EXOSIP_LOCK ();
	rc = eXosip_call_send_initial_invite (invite);
	//if (rc>0) eXosip_call_set_reference(<#int id#>,<#void * reference#>)
	EXOSIP_UNLOCK();
	if (rc<0) return;
	_cid=rc;
	_did=0;

	[self setState:sip_outgoing_call_sent];
}

- (IBAction) dialOutCall:(id) sender
{
	if (state==sip_ondemand) {
		[self registerPhoneOnDemand:YES dur:1800];
	} else if (state != sip_registered) return;
	else [self makeOutCall];
}
- (IBAction) hangUpCall:(id) sender
{
	int rc;
	switch (state) {
		case sip_online:
		case sip_outgoing_call_ringing:
		case sip_outgoing_call_sent:
		case sip_incoming_call_ringing:
			if (_debugFsm) NSLog(@"hang up cid %d did %d\n", _cid, _did);
			rc=eXosip_call_terminate(_cid, _did);
			if (rc<0) NSLog(@"hangup failed %d/%d rc=%d\n", _cid, _did, rc);
			else {
				[self setState:sip_initiated_clearing];
			}
			break;
		default:
			break;
	}
}

- (IBAction) terminateCall:(id) sender
{
	int rc;
	if (_debugFsm) NSLog(@"terminate call cid %d did %d\n", _cid, _did);

	[userPlane endUserPlane];

	switch (state) {
		case sip_online:
		case sip_outgoing_call_ringing:
		case sip_outgoing_call_sent:
		case sip_incoming_call_ringing:
			if (_debugFsm) NSLog(@"eXosip_call_terminate up cid %d did %d\n", _cid, _did);
			rc=eXosip_call_terminate(_cid, _did);
			if (rc<0) NSLog(@"hangup failed %d/%d\n", _cid, _did);
			break;
		default:
			break;
	}
	if ([appHelper onDemandRegister]) {
		if (_debugFsm) NSLog(@"terminateCall/onDemandRegister\n", _cid, _did);
		[self setState:sip_registered];
		[self unregisterPhone:self];
	} else {
		if (_debugFsm) NSLog(@"terminateCall/normalreg\n", _cid, _did);
		[self setState:sip_registered];
	}
}

- (IBAction) acceptCall:(id) sender
{
	if (state != sip_incoming_call_ringing) return;
	
	osip_message_t *answer=NULL;
	eXosip_call_build_answer(_tid, 200, &answer);
	osip_message_set_body (answer, [localSdp cString], [localSdp length]);
	osip_message_set_content_type (answer, "application/sdp");
	EXOSIP_LOCK ();
	int rc=eXosip_call_send_answer (_tid, 200, answer);
	EXOSIP_UNLOCK ();
	[self setState:sip_incoming_call_acccepted];
	if (rc) NSLog(@"accept call failed\n");
}


- (void) setAudioTest:(BOOL) test
{
	if (test != audioTest) {
		audioTest=test;
		if (test) {
			NSLog(@"start audio test\n");
			[userPlane startAudioTestWith:appHelper];
		} else {
			NSLog(@"stop audio test\n");
			[userPlane stopAudioTest];
		}
	}
}
- (BOOL) audioTest
{
	return audioTest;
}

- (IBAction) test1:(id) sender
{
	[userPlane localTone:3];
}
- (IBAction) test2:(id) sender
{
	[userPlane endUserPlane];
}

- (IBAction) pauseApps:(id) sender
{
	[appHelper pauseApps];
}
- (IBAction) ring:(id) sender
{
	[userPlane startRing];
}
- (IBAction) endRing:(id) sender
{
	[userPlane stopRing];
}
- (IBAction) fakeInCall:(id) sender
{
	[popupInCall makeKeyAndOrderFront:self];
}
- (IBAction) dtmf:(id) sender
{
	int tag=[sender tag];
	NSLog(@"dtmf %d\n", tag);
	[userPlane dtmf:@"111"];
}
@end
