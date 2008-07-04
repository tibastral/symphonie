//
//  ABCache.h
//  symPhonie
//
//  Created by Daniel Braun on 23/10/07.
//  Copyright 2007 Daniel Braun. All rights reserved.
//

/*
 * cache of adress book. mostly needed to provide easy per phone number search
 */

#import <Cocoa/Cocoa.h>
#import <AddressBook/AddressBook.h>

//@class ABPerson;

@interface ABCache : NSObject {
	NSMutableDictionary *perPhone;
}

- (ABPerson *) findByPhone:(NSString *)phone;
- (NSArray *) allPhones;
@end

@interface ABPerson (DBExt)
- (NSString *) fullName;
@end
