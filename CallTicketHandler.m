//
//  CallTicketHandler.m
//  symPhonie
//
//  Created by Daniel Braun on 16/11/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "CallTicketHandler.h"
#import "Properties.h"
#import "sipPhone.h"

@implementation CallTicketHandler

- (id) init
{
	self = [super init];
	if (self != nil) {
		//
	}
	return self;
}

- (void) clearInfo
{
	[name release]; name=nil;
	[number release]; number=nil;
	[startCall release]; startCall=nil;
	[startOnline release]; startOnline=nil;
}


- (void) dealloc
{
	[self clearInfo];
	[super dealloc];
}

- (void) addToHistoryTicket:(NSDictionary *)ticket
{
	if (1) {
		NSMutableArray *h=getProp(@"history", [NSMutableArray arrayWithCapacity:1000]);
		[h addObject:ticket];
		setProp(@"history", h);
		[historyController setSelectionIndex:[h count]-1];
	} else {
		[historyController addObject:ticket];
	}
	
}
#if 0
- (void) addToHistoryEvent:(NSString *)event forNum:(NSString *)num duration:(NSTimeInterval)dur
{
	if (!num) num=@"unknown";
	NSDictionary *entry=[NSDictionary dictionaryWithObjectsAndKeys:
			     [NSDate date], @"date",
			     event, @"event",
			     num, @"number",
			     [NSNumber numberWithDouble:dur], @"duration",
			     nil];
	[self addToHistoryTicket:entry];
}
#endif
- (void) setForeignNum:(NSString *) aNum
{
	if (number != aNum) {
		[number release];
		number=[aNum retain];
	}
}
- (void) setForeignName:(NSString *) aName
{
	if (name != aName) {
		[name release];
		name=[aName retain];
	}
}
- (void) tickStartInRing
{
	[self clearInfo];
	callDir=calldirIn;
	startCall=[[NSDate date]retain];
}
- (void) tickStartOutCall
{
	[self clearInfo];
	callDir=calldirOut;
	startCall=[[NSDate date]retain];
}
- (void) tickOnline
{
	[startOnline release];
	startOnline=[[NSDate date]retain];
}
- (void) tickHangupCause:(int) cause info:(NSString *)info
{
	if (!startCall) return; // duplicate hangup
	if (!name) name=NSLocalizedString(@"unknown", @"unknown");
	if (!number) number=NSLocalizedString(@"unknown", @"unknown");
	NSString *evd;
	switch (cause) {
		case 0: evd=@"";break;
		case -2: evd=NSLocalizedString(@"canceled ", @"canceled "); break;
		default: evd=[NSString stringWithFormat:NSLocalizedString(@"failed %d ", @"failed %d "), cause]; break;
	}
	switch (callDir) {
		case calldirIn: evd=[evd stringByAppendingString:NSLocalizedString(@"incoming call", @"incall")]; break;
		case calldirOut: evd=[evd stringByAppendingString:NSLocalizedString(@"outgoing call", @"outcall")]; break;
		default: evd=[evd stringByAppendingString:@"?"]; break;
	}
	NSTimeInterval callduration=0;
	NSTimeInterval ringDuration=0;
	NSDate *now=[NSDate date];
	if (startOnline) {
		callduration=[now timeIntervalSinceDate:startOnline];
		ringDuration=[startOnline timeIntervalSinceDate:startCall];
	} else {
		callduration=0;
		ringDuration=[now timeIntervalSinceDate:startCall];
	}
	NSDictionary *entry=[NSDictionary dictionaryWithObjectsAndKeys:
			     startCall, @"date",
			     evd, @"event",
			     number, @"number",
			     name, @"name",
			     [NSNumber numberWithDouble:callduration], @"duration",
			     [NSNumber numberWithDouble:ringDuration], @"ringDuration",

			     nil];
	[self addToHistoryTicket:entry];
	[self clearInfo];
	
}



- (IBAction) testEntry:(id)sender
{
	//[self addToHistoryEvent:@"test" forNum:@"0101010101" duration:1.0];
}

- (void) setSelectedEntries:(NSIndexSet *)si
{
	if (selectedEntries!=si) {
		[selectedEntries release];
		selectedEntries=[si retain];
		id x=[historyController selectedObjects];
		if (!x)  return;
		if (![x count]) return;
		NSDictionary *v=[x objectAtIndex:0];
		//NSLog(@"selected %@\n", v);
		NSString *num=[v objectForKey:@"number"];
		[phone setSelectedNumber:num];
	}
}
@end
