//
//  StringCallNumber.m
//  symPhonie
//
//  Created by Daniel Braun on 21/10/07.
//  Copyright 2007 Daniel Braun. All rights reserved.
//

#import "StringCallNumber.h"


@implementation PhoneNumberConverter 

static PhoneNumberConverter *defaultConverter=NULL;

- (void) dealloc
{
	[_nationalPrefix release];
	[_internationalPrefix release];
	[_internationalPrefix2 release];
	[_converterDef release];
	if (self==defaultConverter) defaultConverter=NULL;
	[super dealloc];
}


- (id) init
{
	self = [super init];
	if (self != nil) {
		_nationalPrefix=@"0";
		_internationalPrefix=@"+33";
		_internationalPrefix2=@"0033";
		_converterDef=[[NSArray arrayWithObjects:
			       @"I # ## ## ## ##",
			       @"0 82# ### ###",
			       @"I 82# ### ###",
			       @"## ## ## ## ##",
			       @"## ## ## ## #",
			       @"## ## ## ##",
			       @"## ## ## #",
			       @"## ## ##",
			       @"## ## #",
			       @"## ##",
			       @"###",
			       NULL]retain];
		if (!defaultConverter) defaultConverter=self;
	}
	return self;
}

- (void) setConverterDef:(NSArray *)def
{
	if (def != _converterDef) {
		[_converterDef release];
		_converterDef=[def retain];
	}
}

- (NSArray *) converterDef
{
	return _converterDef;
}
- (NSString *) nationalPrefix
{
	return _nationalPrefix;
}

- (NSString *) internationalPrefix
{
	return _internationalPrefix;
}
- (NSString *) internationalPrefix2
{
	return _internationalPrefix2;
}

- (void) setInternationalPrefix:(NSString *)num	// e.g; +33
{
	if (num != _internationalPrefix) {
		[_internationalPrefix release];
		_internationalPrefix=[num retain];
	}
}
- (void) setInternationalPrefix2:(NSString *)num	// e.g; +33
{
	if (num != _internationalPrefix2) {
		[_internationalPrefix2 release];
		_internationalPrefix2=[num retain];
	}
}

- (void) setNationalPrefix:(NSString *)num		// e.g. 0
{
	if (num != _nationalPrefix) {
		[_nationalPrefix release];
		_nationalPrefix=[num retain];
	}
}

+ (PhoneNumberConverter *) defaultConverter
{
	return defaultConverter;
}
- (void) setIsDefault
{
	defaultConverter=self; // not retained
}


static NSString * _callNumber(NSString *str)
{
	char szTmp[128];
	if ([str length]>=sizeof(szTmp)) return nil;
	const char *s=[str cString];
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
	
	return sr;
}

- (NSString *) callNumberFor:(NSString *)n
{
	return _callNumber(n);
}
- (NSString *) internationalCallNumberFor:(NSString *)n
{
	NSString *s=_callNumber(n);
	NSString *np, *ip, *ip2;
	np=[self nationalPrefix];
	ip=[self internationalPrefix];
	ip2=[self internationalPrefix2];
	if (np && ip && ([s hasPrefix:np] && ![s hasPrefix:@"+"] && ![s hasPrefix:@"00"])) {
		NSString *r=[s substringFromIndex:[np length]];
		r=[ip stringByAppendingString:r];
		return r;
	}
	return s;
}
- (NSString *) nationalCallNumberFor:(NSString *)n
{
	NSString *s=_callNumber(n);
	NSString *np, *ip, *ip2;
	np=[self nationalPrefix];
	ip=[self internationalPrefix];
	ip2=[self internationalPrefix2];
	
	if (np && ip && ([s hasPrefix:ip] || ([s hasPrefix:ip2]))) {
		NSString *r=[s substringFromIndex:[ip length]];
		r=[np stringByAppendingString:r];
		return r;
	}
	return s;
	
}

- (NSString *) _match:(NSString *)num template:(NSString *) template
{
	const char *cnum=[num cString];
	const char *ct=[template cString];
	if (!ct) return NULL;
	if (!cnum) return NULL;
	unsigned int l=strlen(ct);
	char szRes[128];
	if (l>sizeof(szRes)-1) return NULL;
	const char *pt=ct;
	const char *pn=cnum;
	char *r=szRes;
	for (pt=ct; *pt; pt++) {
		if (' '==*pt) {
			*r=' '; r++;
			continue;
		} 
		if ('I'==*pt) {
			const char *z=[[self internationalPrefix] cString];
			if (!z) continue;
			if (!strncmp(z, pn, strlen(z))) {
				strcpy(r, z);
				r+=strlen(z);
				pn+=strlen(z);
				continue;
			}
		} else if ('#'==*pt) {
			if (isdigit(*pn)) {
				*r=*pn;
				r++;
				pn++;
				continue;
			}
		} else if ('+'==*pt) {
			if ('+'==*pn) {
				*r='+';
				r++; pn++;
				continue;
			}
		} else if (isdigit(*pt)) {
			if (*pn==*pt) {
				*r=*pn;
				r++; pn++;
				continue;
			}
		} else {
			*r=*pt; r++;
			continue;
		} 
		return NULL;
	}
	*r='\0';
	if (*pn) return NULL;
	if (r==szRes) return NULL;	
	return [NSString stringWithCString:szRes];
}

- (NSString *) _applyFormatFor:(NSString *)n
{
	NSArray *cd=[self converterDef];
	unsigned int i, count = [cd count];
	for (i = 0; i < count; i++) {
		NSString * def = [cd objectAtIndex:i];
		NSString *r=[self _match:n template:def];
		if (r) return r;
	}
	return n;
}
- (NSString *) displayCallNumberFor:(NSString *)n
{
	n=[self callNumberFor:n];
	return [self _applyFormatFor:n];
}

- (NSString *) internationalDisplayCallNumberFor:(NSString *)n
{
	n=[self callNumberFor:n];
	NSString *s= [self _applyFormatFor:n];
	return s;
}

@end





/* 20071114
 * quick and dirty (actually more dirty than quick!) code to format call numbers
 * need complete refactoring so it can be configurable
 * interface is ok however
 */
@implementation NSString (StringCallNumber)
- (NSString *) callNumber
{
	return [[PhoneNumberConverter defaultConverter] callNumberFor:self];
}
- (NSString *) internationalCallNumber
{
	return [[PhoneNumberConverter defaultConverter] internationalCallNumberFor:self];
}

- (NSString *) internationalDisplayCallNumber
{
	return [[PhoneNumberConverter defaultConverter] internationalDisplayCallNumberFor:self];
}

- (NSString *) displayCallNumber
{
	return [[PhoneNumberConverter defaultConverter] displayCallNumberFor:self];
}


@end
