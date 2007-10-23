//
//  ABCache.m
//  sipPhone
//
//  Created by Daniel Braun on 23/10/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "ABCache.h"
#import "StringCallNumber.h"
#import <AddressBook/AddressBook.h>

@implementation ABCache

- (void) dealloc {
	[perPhone release];
	[super dealloc];
}

- (void) _abChanged:(NSNotification*)notif 
{
	[perPhone release];
	perPhone=nil;
}

- (void) _abCachePopulate
{
	if (perPhone) return;
	perPhone=[[NSMutableDictionary dictionaryWithCapacity:200]retain];
	ABAddressBook *ab=[ABAddressBook sharedAddressBook];
	NSArray *people=[ab people];
	unsigned int i, count = [people count];
	for (i = 0; i < count; i++) {
		ABPerson * person = [people objectAtIndex:i];
		//NSLog(@"got %@\n", obj);
		ABMultiValue *phones = [person valueForProperty:kABPhoneProperty];
		int j, k;
		k=[phones count];
		for (j=0; j<k; j++) {
			NSString *s=[phones valueAtIndex:j];
			s=[s cannonicalCallNumber];
			[perPhone setObject:person forKey:s];
			//NSLog(@"got %@\n", s);
		}
		
	}	

}

- (id) init {
	self = [super init];
	if (!self) return nil;
	ABAddressBook *ab=[ABAddressBook sharedAddressBook];
	[[NSNotificationCenter defaultCenter]  addObserver:self
						  selector:@selector(_abChanged:)
						      name:kABDatabaseChangedExternallyNotification
						    object:ab];  
	[self _abCachePopulate];
	return self;
}

- (ABPerson *) findByPhone:(NSString *)phone
{
	if (!perPhone) [self _abCachePopulate];
	phone=[phone cannonicalCallNumber];
	ABPerson *p=[perPhone objectForKey:phone];
	return p;
}
@end
