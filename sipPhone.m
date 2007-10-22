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
	}
	return self;
}
- (void) dealloc {
	[selectedNumber release];
	[selectedName release];
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
	
	array = [picker selectedRecords];
	NSArray *a2=[picker selectedValues];
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
	NSAssert(picker, @"unconnected picker");
	//[picker setTarget:self];
	[picker setAllowsMultipleSelection:NO];
	[picker setValueSelectionBehavior:ABSingleValueSelection];
	//[picker setNameDoubleAction:@selector(abDClicked:)];
	//Here we set up a responder for one of the four notifications,
	//in this case to tell us when the selection in the name list
	//has changed.
	NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
	if (0) [center addObserver:self
		   selector:@selector(recordChange:)
		       name:ABPeoplePickerNameSelectionDidChangeNotification
		     object:picker];
	[center addObserver:self
		   selector:@selector(recordChange:)
		       name:ABPeoplePickerValueSelectionDidChangeNotification
		     object:picker];
	
	[picker deselectAll:self];
	[self _initExosip];
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
	
	[self willChangeValueForKey:@"incomingCallActive"];
	[self willChangeValueForKey:@"outgoingCallActive"];
	[self willChangeValueForKey:@"onCallActive"];
	[self willChangeValueForKey:@"selectedViewNumber"];
	[self willChangeValueForKey:@"isRinging"];
	state=s;
	if (state==sip_registered) [self setAbVisible:YES];
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
	
	
	for (;;)	{
		je = eXosip_event_wait (0, 0);
		eXosip_lock();
		eXosip_automatic_action ();
		eXosip_unlock();
		if (je == NULL) break;
		NSLog(@"event %d (%s) tid %d cid %d\n", je->type, je->textinfo, je->tid, je->cid);

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
			case EXOSIP_CALL_INVITE:
				NSLog(@"incoming call\n");
								
				//if (je->request) remote_sdp = eXosip_get_sdp_info (je->request);
				//if (!remote_sdp) break;
				//conn = eXosip_get_audio_connection (remote_sdp);
				//remote_med = eXosip_get_audio_media (remote_sdp);
				
				eXosip_call_send_answer (je->tid, 415, NULL);
			case EXOSIP_CALL_PROCEEDING:
				break;
			case EXOSIP_CALL_RINGING:
				[self setState:sip_outgoing_call_ringing];
				break;
			case EXOSIP_CALL_ANSWERED:
				NSLog(@"call answered\n");
				
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

	[self setState:sip_outgoing_call_sent];
}

- (IBAction) dialOutCall:(id) sender
{
	if (state != sip_registered) return;
	[self makeOutCall];
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
