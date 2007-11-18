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

- (NSString *) phoneNum:(ABPerson *)person forId:(NSString *) identifier intl:(BOOL) intl
{
	ABMultiValue* phones = [person valueForProperty:kABPhoneProperty];
	int k=[phones count];
	if (k<1) return nil;
	unsigned int idx=[phones indexForIdentifier:identifier];
	if ( NSNotFound ==idx) idx=0;
	NSString *value=[phones valueAtIndex:idx];
	return intl ? [value internationalCallNumber] : value ;
}
	
- (NSString *)titleForPerson:(ABPerson *)person identifier:(NSString *)identifier
{
	//NSLog(@"titleForPerson/id=%@\n", identifier);
	NSString* cnum = [self phoneNum:person forId:identifier intl:NO];

	return [NSString stringWithFormat:@"sipPhone: %@", cnum];    
}

// This method is called when the user selects your action. As above, this method
// is passed information about the data item rolled over.

- (void)performActionForPerson:(ABPerson *)person identifier:(NSString *)identifier
{
	//NSLog(@"performActionForPerson/id=%@\n", identifier);
	//NSString* value = [values valueForIdentifier:identifier];
	NSString *personName;
	NSString *n1=[person valueForProperty:kABFirstNameProperty];
	//NSLog(@"n1=%@\n", n1?n1:@"nil");
	NSString *n2=[person valueForProperty:kABLastNameProperty];
	//NSLog(@"n2=%@\n", n2?n2:@"nil");
	if (!n2) personName=n1;
	else if (!n1) personName=n2;
	else personName  = [NSString stringWithFormat:@"%@ %@",n1,n2];
	
	
	
	NSString *cnum=[[self phoneNum:person forId:identifier intl:NO]stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	personName=[personName stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSURL *dialUrl=[NSURL URLWithString:[NSString stringWithFormat:@"sipPhone:%@;%@", cnum,personName]];
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
