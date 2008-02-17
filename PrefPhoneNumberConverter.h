//
//  PrefPhoneNumberConverter.h
//  sipPhone
//
//  Created by Daniel Braun on 10/12/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "StringCallNumber.h"

@interface PrefPhoneNumberConverter : PhoneNumberConverter {

}

- (void) setConverterDef:(NSArray *)def;
- (void) setInternationalPrefix:(NSString *)num;	// e.g; +33
- (void) setInternationalPrefix2:(NSString *)num;	// e.g; +33
- (void) setNationalPrefix:(NSString *)n;		// e.g. 0
- (NSString *) nationalPrefix;
- (NSString *) internationalPrefix;
- (NSString *) internationalPrefix2;
- (NSArray *) converterDef;

+ (NSArray *) defaultPrefValue;
@end
