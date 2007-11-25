//
//  StringCallNumber.h
//  sipPhone
//
//  Created by Daniel Braun on 21/10/07.
//  Copyright 2007 Daniel Braun. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PhoneNumberConverter : NSObject
{
	NSString *nationalPrefix;
	NSString *internationalPrefix;
	NSArray *converterDef;
}
- (void) setConverterDef:(NSArray *)def;
- (void) setInternationalPrefix:(NSString *)num;	// e.g; +33
- (void) setNationalPrefix:(NSString *)n;		// e.g. 0
- (NSString *) callNumberFor:(NSString *)n;
- (NSString *) displayCallNumberFor:(NSString *)n;
- (NSString *) internationalCallNumberFor:(NSString *)n;
- (NSString *) internationalDisplayCallNumberFor:(NSString *)n;

+ (PhoneNumberConverter *) defaultConverter;
- (void) setIsDefault;

@end

@interface NSString (StringCallNumber)

- (NSString *) internationalCallNumber;
- (NSString *) internationalDisplayCallNumber;
- (NSString *) callNumber;
- (NSString *) displayCallNumber;


@end
