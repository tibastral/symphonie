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

- (void) dealloc
{
	[super dealloc];
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
	NSMutableArray *h=getProp(@"history", [NSMutableArray arrayWithCapacity:1000]);
	[h addObject:entry];
	setProp(@"history", h);
}

- (IBAction) testEntry:(id)sender
{
	[self addToHistoryEvent:@"test" forNum:@"0101010101" duration:1.0];
}

@end
