//
//  StringCallNumber.m
//  sipPhone
//
//  Created by Daniel Braun on 21/10/07.
//  Copyright 2007 Daniel Braun. All rights reserved.
//

#import "StringCallNumber.h"


@implementation NSString (StringCallNumber)

- (NSString *) cannonicalCallNumber
{
	char szTmp[128];
	//NSMutableString *s2=[self mutableCopy];
	//[s2 replaceOccurrencesOfString:@" " withString:@""  options:NSLiteralSearch range:NSMakeRange(0,[s2 length])];
	//[s2 autorelease]
	if ([self length]>=sizeof(szTmp)) return nil;
	const char *s=[self cString];
	if (!s) return nil;
	int i;
	for (i=0; *s; s++) {
		if (!isdigit(*s) && (*s!='#') && (*s!='*')) {
			if (i || (*s!='+')) continue;
		}
		szTmp[i]=*s;
		i++;
	}
	szTmp[i]='\0';
	NSString *sr=[NSString stringWithCString:szTmp];
	if ([sr hasPrefix:@"0"]) {
		sr=[NSString stringWithFormat:@"%@%s", @"+33", szTmp+1];
	}
	return sr;
}
- (NSString *) cannonicalDisplayCallNumber
{
	NSString *s;
	//char szTmp[1024];

	s=[self cannonicalCallNumber];
	//int i;
	//const char *z=[self cString];
	
	return s;
}

@end
