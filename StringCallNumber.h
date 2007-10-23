//
//  StringCallNumber.h
//  sipPhone
//
//  Created by Daniel Braun on 21/10/07.
//  Copyright 2007 Daniel Braun. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSString (StringCallNumber)

- (NSString *) cannonicalCallNumber;
- (NSString *) cannonicalDisplayCallNumber;

@end
