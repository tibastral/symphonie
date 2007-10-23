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

#import <AddressBook/AddressBook.h>

#import <Carbon/Carbon.h>

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

@implementation sipPhone

static int initDone=0;

- (id) init {
	self = [super init];
	if (self != nil) {
		userPlane=[[UserPlane alloc]init];
		abCache=[[ABCache alloc]init];
		abVisibleOffline=YES;
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

- (void) awakeFromNib
{
	NSAssert(abPicker, @"unconnected abPicker");
	//[abPicker setTarget:self];
	[abPicker setAllowsMultipleSelection:NO];
	[abPicker setValueSelectionBehavior:ABSingleValueSelection];
	//[abPicker setNameDoubleAction:@selector(abDClicked:)];
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
	
	[abPicker deselectAll:self];
	[self _initExosip];
	
	popupInCall = [[NSWindow alloc] initWithContentRect:[popupInCallView frame]
						  styleMask:NSBorderlessWindowMask
						    backing:NSBackingStoreBuffered defer:YES];
	[popupInCall setBackgroundColor:[NSColor blackColor]];
	[popupInCall setExcludedFromWindowsMenu:YES];
	[popupInCall setLevel:NSScreenSaverWindowLevel];
	[popupInCall setShowsToolbarButton:NO];
	[popupInCall setAlphaValue:0.55];
	[popupInCall setOpaque:NO];
	[popupInCall setHasShadow:NO];
	[popupInCall setMovableByWindowBackground:YES];
	[popupInCall center];
	[popupInCall setContentView:popupInCallView];
	//long vol;
	//GetDefaultOutputVolume(&vol);
	//SetDefaultOutputVolume(vol*4);
	[self setCallingNumber:@"01 39 46 50 50"];
}


- (void) setSelectedNumber:(NSString *)s
{
	if (selectedNumber != s) {
		[self willChangeValueForKey:@"cannonicalSelectedNumber"];
		[selectedNumber release];
		selectedNumber=[s retain];
		[self setFromAB:NO];
		[self didChangeValueForKey:@"cannonicalSelectedNumber"];
	}
}
- (NSString*) selectedNumber
{
	return selectedNumber;
}
- (NSString*) cannonicalSelectedNumber
{
	return [selectedNumber cannonicalCallNumber];
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
	return [callingNumber cannonicalDisplayCallNumber];
}


- (void) setCallingNumber:(NSString *)s
{
	if (s!=callingNumber) {
		[self willChangeValueForKey:@"cannonicalCallingNumber"];
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
		[self didChangeValueForKey:@"cannonicalCallingNumber"];

	}
}
- (NSString*) cannonicalCallingNumber
{
	return [callingNumber cannonicalCallNumber];
}
- (NSString *) callingNumber
{
	return [callingNumber cannonicalDisplayCallNumber];
}

- (BOOL) fromAB
{
	return fromAB;
}
- (void) setFromAB:(BOOL)f
{
	fromAB=f;
}
/*
 * ============== phone itself ===============
 */
- (int) selectedViewNumber
{
	switch (state) {
		case sip_off: return 0;
		case sip_register_in_progress: return 0;
		case sip_register_retry: return 0;
		case sip_registered: return 1;
		case sip_outgoing_call_sent: return 2;
		case sip_outgoing_call_ringing: return 2;
		case sip_online: return 3;
		case sip_initiated_clearing: return 4;
		case sip_incoming_call_ringing: return 5;
		default: return 1;
	}
}

- (NSString *) windowTitle
{
	return @"sipPhone";
}

- (BOOL) abVisible
{
	return abVisible;
}
- (void) setAbVisible:(BOOL)f
{
	if (sip_registered==state) abVisibleOffline=f;
	abVisible=f;
}
- (BOOL) isRinging
{
	return (state==sip_outgoing_call_ringing);
}

- (void) setState:(sipState_t) s
{
	if (state==s) return;
	// some hook when leaving a state
	if (state==sip_registered) [self setAbVisible:NO];
	if (state==sip_incoming_call_ringing) [popupInCall orderOut:self];
	[self willChangeValueForKey:@"incomingCallActive"];
	[self willChangeValueForKey:@"outgoingCallActive"];
	[self willChangeValueForKey:@"onCallActive"];
	[self willChangeValueForKey:@"selectedViewNumber"];
	[self willChangeValueForKey:@"isRinging"];
	state=s;
	if (state==sip_registered) [self setAbVisible:abVisibleOffline];
	if (1 || (state==sip_incoming_call_ringing)) {
		[mainWin makeKeyAndOrderFront:self];
	}
	if (state==sip_incoming_call_ringing) {
		[popupInCall makeKeyAndOrderFront:self];
	}
	[self didChangeValueForKey:@"isRinging"];
	[self didChangeValueForKey:@"selectedViewNumber"];
	[self didChangeValueForKey:@"incomingCallActive"];
	[self didChangeValueForKey:@"outgoingCallActive"];
	[self didChangeValueForKey:@"onCallActive"];
	
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
			return YES;
	}
	return NO;
}
- (BOOL) onCallActive
{
	switch (state) {
		default: 
			break;
	}
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
	
	pollTimer=[NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)0.1 
					  target:self selector:@selector(pollExosip:) userInfo:nil repeats:YES];
}



- (BOOL) registerPhone
{
	osip_message_t *reg = NULL;
	int regid;
	int rc;
	
	NSAssert(state==sip_off, @"bad state for registerPhone");
	eXosip_lock ();
	regid = eXosip_register_build_initial_register ("sip:0952276724@freephonie.net", "sip:freephonie.net","sip:0952276724@freephonie.net",
						     1800, &reg);
	if (regid < 0)
	{
		eXosip_unlock ();
		NSAssert(0, @"registered failed\n");
		return -1;
	}
	
	eXosip_add_authentication_info("0952276724", "0952276724",
					   "lkjsdf4242", NULL, NULL);
	
	if (1) osip_message_set_supported (reg, "100rel");
	if (1) osip_message_set_supported(reg, "path");
	
	rc = eXosip_register_send_register (regid, reg);
	eXosip_unlock ();
	NSAssert(!rc, @"eXosip_register_send_register failed\n");
	[self setState:sip_register_in_progress];
	return rc;
}



- (void) pollExosip:(NSTimer *)t
{
	eXosip_event_t *je;
	int rc;
	//sdp_connection_t *conn=NULL;
	//sdp_media_t *local_med=NULL;
	//sdp_media_t *remote_med=NULL;
	//sdp_message_t *remote_sdp = NULL;
	
	
	for (;;) {
		je = eXosip_event_wait (0, 0);
		eXosip_lock();
		eXosip_automatic_action ();
		eXosip_unlock();
		if (je == NULL) break;
		NSLog(@"event %d (%s) tid %d cid %d rid %d did %d\n", je->type, je->textinfo, je->tid, je->cid, je->rid, je->did);
		if (je->rid) {
			switch (je->type) {
				case EXOSIP_REGISTRATION_FAILURE:
					if ((sip_register_in_progress != state) && (sip_register_retry!=state)) break;
					if (sip_register_retry==state) {
						[self setState:sip_off];
						break;
					}
						[self setState:sip_register_retry];
					rc=eXosip_default_action(je);
					if (rc) {
						[self setState:sip_off];
						break;
					}
						break;
				case EXOSIP_REGISTRATION_SUCCESS:
					NSLog(@"registered\n");
					if (state<sip_registered) [self setState:sip_registered];
						break;
				default:
					rc=eXosip_default_action(je);
					break;
			}
		} else if (je->cid) {
			if (_cid != je->cid) {
				if (je->type==EXOSIP_CALL_INVITE) {
					NSLog(@"incoming call\n");
					if (!je->request) goto refuse_call;
					if (!je->request->from) goto refuse_call;
					char *f=je->request->from->displayname;
					if (!f) goto refuse_call;
					[self setCallingNumber:[NSString stringWithCString:f]];
					
					_cid=je->cid;
					_did=je->did;
					_tid=je->tid;
					[remoteSdp release];
					remoteSdp=[eXosip_get_sdp_body(je->response) retain];
					[self didChangeValueForKey:@"remoteSdp"];
					[localSdp release];
					localSdp=[[userPlane setupAndGetLocalSdp]retain];
					[self didChangeValueForKey:@"remoteSdp"];
					[self setState:sip_incoming_call_ringing];
					eXosip_lock ();
					eXosip_call_send_answer (je->tid, 180, NULL);
					eXosip_unlock ();
					break;
refuse_call:
						eXosip_lock ();
					eXosip_call_send_answer (je->tid, 415, NULL);
						eXosip_unlock ();
					
				}
				rc=eXosip_default_action(je);
				eXosip_event_free(je);
				continue;
			}
			switch (je->type) {
				case EXOSIP_CALL_INVITE:NSLog(@"incoming call on existing call?\n");
					eXosip_lock ();
					eXosip_call_send_answer (je->tid, 415, NULL);
					eXosip_unlock ();
					break;
				case EXOSIP_CALL_PROCEEDING:
					break;
				case EXOSIP_CALL_RINGING:
					[self setState:sip_outgoing_call_ringing];
					if (je->did) _did=je->did;
						break;
				case EXOSIP_CALL_REQUESTFAILURE:
					if ((je->response != NULL && je->response->status_code == 407)
					    || (je->response != NULL && je->response->status_code == 401)) {
						rc=eXosip_default_action(je);
						break;
					}
					NSLog(@"EXOSIP_CALL_REQUESTFAILURE\n");
					[self setState:sip_initiated_clearing];
					break;
				case EXOSIP_CALL_SERVERFAILURE:
					NSLog(@"EXOSIP_CALL_SERVERFAILURE\n");
					break;
				case EXOSIP_CALL_GLOBALFAILURE:
					NSLog(@"EXOSIP_CALL_GLOBALFAILURE\n");
					break;
				case EXOSIP_CALL_ANSWERED:
					NSLog(@"call answered\n");
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
					
					BOOL ok=[userPlane setupWithtLocalSdp:localSdp remoteSdp:remoteSdp outCall:YES];
					
					//[self establishUserPlaneLocal:&local_med remote:&remote_med];
					
					osip_message_t *ack;
					rc = eXosip_call_build_ack(je->did, &ack);
					if (rc != 0) {
						NSLog(@"eXosip_call_build_ack failed...\n");
						break;
					}
						eXosip_lock();
					eXosip_call_send_ack(je->did, ack);
					//eXosip_call_terminate (je->cid, je->tid);
					eXosip_unlock();
					[self setState:sip_online];
					break;
				case EXOSIP_CALL_MESSAGE_NEW:
					NSLog(@"msg new (EXOSIP_CALL_MESSAGE_NEW)\n");
					break;
				case EXOSIP_CALL_MESSAGE_PROCEEDING:
					NSLog(@"call proceed\n");
					if (je->did) _did=je->did;
						break;
				case EXOSIP_CALL_RELEASED:
					[userPlane endUserPlane];
					[self setState:sip_registered];
					NSLog(@"call released (EXOSIP_CALL_RELEASED)\n");
					break;
				case EXOSIP_CALL_CLOSED:
					[userPlane endUserPlane];
					[self setState:sip_registered];
					NSLog(@"call released (EXOSIP_CALL_CLOSED)\n");
					break;
				default:
					NSLog(@"not handled event %d (%s)\n", je->type, je->textinfo);
					break;
			}
		} else {
			
			rc=eXosip_default_action(je);
		}
		
		eXosip_event_free(je);
	}
}

- (void) makeOutCall
{
	NSAssert(sip_registered==state, @"bad state for ocall");
	
	osip_message_t *invite = NULL;
	
	int rc;
	rc = eXosip_call_build_initial_invite(&invite,
						  [[NSString stringWithFormat:@"sip:%@@freephonie.net", [self cannonicalSelectedNumber]]cString],
						 "sip:0952276724@freephonie.net",
						 NULL,
						 "phone call");
	if (rc) return;
	osip_message_set_supported (invite, "100rel");
	//NSLog(@"invite tid %d cid %d\n", invite->tid, invite->cid);
	[userPlane endUserPlane];
	
	[self willChangeValueForKey:@"localSdp"];
	[localSdp release];
	localSdp=[[userPlane setupAndGetLocalSdp] retain];
	[self didChangeValueForKey:@"localSdp"];

	osip_message_set_body (invite, [localSdp cString], [localSdp length]);
	osip_message_set_content_type (invite, "application/sdp");
	
	
	eXosip_lock ();
	rc = eXosip_call_send_initial_invite (invite);
	//if (rc>0) eXosip_call_set_reference(<#int id#>,<#void * reference#>)
	eXosip_unlock();
	if (rc<0) return;
	_cid=rc;
	_did=0;

	[self setState:sip_outgoing_call_sent];
}

- (IBAction) dialOutCall:(id) sender
{
	if (state != sip_registered) return;
	[self makeOutCall];
}
- (IBAction) hangUpCall:(id) sender
{
	int rc;
	switch (state) {
		case sip_online:
		case sip_outgoing_call_ringing:
		case sip_outgoing_call_sent:
		case sip_incoming_call_ringing:
			rc=eXosip_call_terminate(_cid, _did);
			if (rc<0) NSLog(@"hangup failed\n");
			else {
				[self setState:sip_initiated_clearing];
			}
			break;
		default:
			break;
	}
}
- (IBAction) acceptCall:(id) sender
{
	if (state != sip_incoming_call_ringing) return;
	eXosip_call_send_answer(_tid,200,NULL);
}

- (IBAction) testMe:(id) sender
{
		[self _initExosip];
	
	[self registerPhone];
}
- (IBAction) pollMe:(id) sender
{
	
	[self pollExosip:nil];
}

- (IBAction) test1:(id) sender
{
	[userPlane localTone:3];
}
- (IBAction) test2:(id) sender
{
	[userPlane endUserPlane];
}


@end
