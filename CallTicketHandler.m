//
//  CallTicketHandler.m
//  sipPhone
//
//  Created by Daniel Braun on 16/11/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "CallTicketHandler.h"
#import "Properties.h"

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

- (void) setForeignNum:(NSString *) aNum
{
	if (number != aNum) {
		[number release];
		number=[aNum retain];
	}
}
- (void) setForeignName:(NSString *) aName
{
}
- (void) tickStartInRing
{
}
- (void) tickStartOutCall
{
}
- (void) tickOnline
{
}
- (void) tickHangupCause:(int) cause info:(NSString *)info
{
}



- (IBAction) testEntry:(id)sender
{
	[self addToHistoryEvent:@"test" forNum:@"0101010101" duration:1.0];
}

@end
