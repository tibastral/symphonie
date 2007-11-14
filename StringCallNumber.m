//
//  StringCallNumber.m
//  sipPhone
//
//  Created by Daniel Braun on 21/10/07.
//  Copyright 2007 Daniel Braun. All rights reserved.
//

#import "StringCallNumber.h"

/* 20071114
 * quick and dirty (actually more dirty than quick!) code to format call numbers
 * need complete refactoring so it can be configurable
 * interface is ok however
 */
@implementation NSString (StringCallNumber)

static NSString * callNumber(NSString *self, BOOL international)
{
	char szTmp[128];
	if ([self length]>=sizeof(szTmp)) return nil;
	const char *s=[self cString];
	if (!s) return nil;
	int i;
	for (i=0; *s && (i<127); s++) {
		if (!isdigit(*s) && (*s!='#') && (*s!='*')) {
			if (i || (*s!='+')) continue;
		}
		szTmp[i]=*s;
		i++;
	}
	szTmp[i]='\0';
	NSString *sr=[NSString stringWithCString:szTmp];
	if (international && [sr hasPrefix:@"0"]) {
		sr=[NSString stringWithFormat:@"%@%s", @"+33", szTmp+1];
	}
	return sr;
}
- (NSString *) callNumber
{
	return callNumber(self, NO);
}
- (NSString *) cannonicalCallNumber
{
	return callNumber(self, YES);
}

#if 0
- (NSString *) cannonicalDisplayCallNumber
{
	NSString *s;
	//char szTmp[1024];

	s=[self cannonicalCallNumber];
	//int i;
	//const char *z=[self cString];
	
	return s;
}
#endif
static NSString * displayCallNumber(NSString *self, BOOL international)
{
	char szTmp[128];
	if ([self length]>=sizeof(szTmp)) return nil;
	const char *s=[self cString];
	if (!s) return nil;
	int i;
	int k;
	for (i=0, k=0; *s && (i<127); s++) {
		if (!isdigit(*s) && (*s!='#') && (*s!='*')) {
			if (i || (*s!='+')) continue;
			if (*s=='+') {
			}
		} else if (international && ('0'==*s) && !i) {
			
			strcpy(szTmp, "+33 ");
			i=4;
			k=0;
			continue;
		}
		
		szTmp[i]=*s;
		i++;
		k++;
		if ((2==i) && ('+'==szTmp[0])) {
			k=1;
		} else if ((5==i) && ('+'==szTmp[0])) {
			k=2;
		}
		if (2==k) {
			szTmp[i++]=' ';
			k=0;
		}
	}
	szTmp[i]='\0';
	NSString *sr=[NSString stringWithCString:szTmp];

	return sr;
}

- (NSString *) cannonicalDisplayCallNumber
{
	return displayCallNumber(self, YES);
}

- (NSString *) displayCallNumber
{
	return displayCallNumber(self, NO);
}


@end
