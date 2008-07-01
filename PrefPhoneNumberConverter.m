//
//  PrefPhoneNumberConverter.m
//  sipPhone
//
//  Created by Daniel Braun on 10/12/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "PrefPhoneNumberConverter.h"
#import "Properties.h"

@implementation PrefPhoneNumberConverter

static NSArray *defRules=nil;

#define _R(_s) [NSDictionary dictionaryWithObject:(_s) forKey:@"rule"]

+ (NSArray *) defaultPrefValue
{
	if (!defRules) {
		defRules=[[NSArray arrayWithObjects:
			   _R(@"I # ## ## ## ##"),
			   _R(@"0 82# ### ###"),
			   _R(@"I 82# ### ###"),
			   _R(@"## ## ## ## ##"),
			   _R(@"## ## ## ## #"),
			   _R(@"## ## ## ##"),
			   _R(@"## ## ## #"),
			   _R(@"## ## ##"),
			   _R(@"## ## #"),
			   _R(@"## ##"),
			   _R(@"###"),
			   NULL]retain];
	}
	return defRules;
}

- (id) init
{
	self = [super init];
	if (self != nil) {
	}
	return self;
}

- (void) setConverterDef:(NSArray *)def
{
	NSAssert(0, @"should not be used\n");
}
- (void) setInternationalPrefix:(NSString *)num
{
	setProp(@"numberInternationalPrefix", num);
}
- (void) setInternationalPrefix2:(NSString *)num
{
	setProp(@"numberInternationalPrefix2", num);
}

- (void) setNationalPrefix:(NSString *)n
{
	setProp(@"numberNationalPrefix", n);
}
- (NSString *) nationalPrefix
{
	return getProp(@"numberNationalPrefix", @"0");
}
- (NSString *) internationalPrefix
{
	return getProp(@"numberInternationalPrefix", @"+33");
}
- (NSString *) internationalPrefix2
{
	return getProp(@"numberInternationalPrefix2", @"0033");
}

- (NSArray *) converterDef
{
	NSArray *p=getProp(@"numberRulesPref", [PrefPhoneNumberConverter defaultPrefValue]);
	int i, count = [p count];
	NSMutableArray *res=[NSMutableArray arrayWithCapacity:count];

	for (i = 0; i < count; i++) {
		NSDictionary * dr = [p objectAtIndex:i];
		NSString *r=[dr objectForKey:@"rule"];
		if (r) [res addObject:r];
	}
	return res;
}


@end
