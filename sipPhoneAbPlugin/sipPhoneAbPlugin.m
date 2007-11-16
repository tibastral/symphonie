//
//  sipPhoneAbPlugin.m
//  sipPhoneAbPlugin
//
//  Created by Daniel Braun on 16/11/07.
//  Copyright __MyCompanyName__ 2007. All rights reserved.
//

#import "sipPhoneAbPlugin.h"
#import "StringCallNumber.h"

@implementation sipPhoneAbPlugin

// This example action works with phone numbers.
- (NSString *)actionProperty
{
    return kABPhoneProperty;
}

// Our menu title will look like Speak 555-1212
- (NSString *)titleForPerson:(ABPerson *)person identifier:(NSString *)identifier
{
    ABMultiValue* values = [person valueForProperty:[self actionProperty]];
    NSString* value = [values valueForIdentifier:identifier];

    return [NSString stringWithFormat:@"sipPhone %@", value];    
}

// This method is called when the user selects your action. As above, this method
// is passed information about the data item rolled over.

- (void)performActionForPerson:(ABPerson *)person identifier:(NSString *)identifier
{
	ABMultiValue* values = [person valueForProperty:[self actionProperty]];
	NSString* value = [values valueForIdentifier:identifier];
	NSString *cnum=[value internationalCallNumber];
	NSURL *dialUrl=[NSURL URLWithString:[NSString stringWithFormat:@"sipPhone:%@", cnum]];
	NSLog(@"built url: %@\n", dialUrl);
	[[NSWorkspace sharedWorkspace] openURL:dialUrl];
}

// Optional. Your action will always be enabled in the absence of this method. As
// above, this method is passed information about the data item rolled over.
- (BOOL)shouldEnableActionForPerson:(ABPerson *)person identifier:(NSString *)identifier
{
    return YES;
}

@end
