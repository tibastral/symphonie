//
//  ABCache.h
//  sipPhone
//
//  Created by Daniel Braun on 23/10/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ABPerson;

@interface ABCache : NSObject {
	NSMutableDictionary *perPhone;
}

- (ABPerson *) findByPhone:(NSString *)phone;
@end
