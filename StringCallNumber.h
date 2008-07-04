//
//  StringCallNumber.h
//  symPhonie
//
//  Created by Daniel Braun on 21/10/07.
//  Copyright 2007 Daniel Braun. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/*
 * convertion of phone call for
 * - pretty printing
 * - replacing eg of national prefix (eg "0") by international one (eg "+33")
 */

@interface PhoneNumberConverter : NSObject
{
	NSString *_nationalPrefix;
	NSString *_internationalPrefix;
	NSString *_internationalPrefix2;
	NSArray *_converterDef;
}
- (void) setConverterDef:(NSArray *)def;
- (void) setInternationalPrefix:(NSString *)num;	// e.g; +33
- (void) setInternationalPrefix2:(NSString *)num;	// e.g; 00
- (void) setNationalPrefix:(NSString *)n;		// e.g. 0
- (NSString *) nationalPrefix;
- (NSString *) internationalPrefix;
- (NSString *) internationalPrefix2;
- (NSArray *) converterDef;

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
