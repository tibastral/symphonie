//
//  UpdateChecker.m
//  sipPhone
//
//  Created by Daniel Braun on 16/02/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "UpdateChecker.h"


@implementation UpdateChecker



static inline id getProp(NSString *k, id defaultValue)
{
	id pref=[[NSUserDefaultsController sharedUserDefaultsController] values];
	id v=[pref valueForKey:k]; 
	if (!v && defaultValue) {
		[pref setValue:defaultValue forKey:k];
		v=defaultValue;
	}
	return v;
}
static inline BOOL getBoolProp(NSString *k, BOOL defaultValue)
{
	return [getProp(k, [NSNumber numberWithBool:defaultValue]) boolValue];
}

- (id) init
{
	self = [super init];
	if (self != nil) {
		receivedData=[[NSMutableData dataWithCapacity:(1024*2)] retain];
		if (getBoolProp(@"checkForUpdate", YES))[self getUpdateInfos];

	}
	return self;
}
- (void) dealloc
{
	[cnx release];
	[receivedData release];
	[properties release];
	[appName release];
	[latestVersion release];
	[super dealloc];
}
- (void) awakeFromNib
{
	[updateWindow makeKeyAndOrderFront:self];
}


- (void) getUpdateInfos
{
	NSURL *url;
	[appName release];
	appName=[[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleExecutable"]retain];
	url=[NSURL URLWithString:[NSString stringWithFormat:
				  @"http://page-appart.net/assets/%@.plist", appName]];
	NSMutableURLRequest *req=[[[NSMutableURLRequest alloc] init]autorelease];
	[req setCachePolicy:NSURLRequestReloadIgnoringCacheData];
	[req setTimeoutInterval:60.0];
	[req setHTTPMethod:@"GET" ];
	[req setURL:url];
	[receivedData setLength:0];
	cnx=[[NSURLConnection alloc] initWithRequest:req delegate:self];
}

static BOOL isMoreRecent(int a1, int a2, int a3, int b1, int b2, int b3)
{
	if (a1>b1) return YES;
	if (a1<b1) return NO;
	if (a2>b2) return YES;
	if (a2<b2) return NO;
	if (a3>b3) return YES;
	return NO;
}

- (void) loadSuccess:(NSData *)data
{
	[properties release];
	NSString *err=nil;
	properties=[[ NSPropertyListSerialization propertyListFromData:data 
						      mutabilityOption:NSPropertyListImmutable 
								format:NULL 
						      errorDescription:&err] retain];
	if (!properties) {
		NSLog(@"error loading update info: %@\n", err);
		return;
	}
	NSLog(@"got update info %@\n", properties);
	NSBundle *mb=[NSBundle mainBundle];
	//- (id)objectForInfoDictionaryKey:(NSString *)key
	NSString *curVersion=[mb objectForInfoDictionaryKey:@"CFBundleVersion"];
	//NSDictionary *bi=[mb infoDictionary];
	NSLog(@"cv %@\n", curVersion);
	NSArray *vi=[curVersion componentsSeparatedByString:@"."];
	if ([vi count] != 3) {
		NSLog(@"cur version %@ bad format\n", curVersion);
		return;
	}
	int major, nmajor, minor, nminor, level, nlevel;
	nmajor=[[properties valueForKeyPath:@"version.A"]intValue];
	nminor=[[properties valueForKeyPath:@"version.B"]intValue];
	nlevel=[[properties valueForKeyPath:@"version.C"]intValue];
	[latestVersion release];
	latestVersion=[[NSString stringWithFormat:@"%d.%d.%d", nmajor, nminor, nlevel]retain];
	major=[[vi objectAtIndex:0]intValue];
	minor=[[vi objectAtIndex:1]intValue];
	level=[[vi objectAtIndex:2]intValue];
	if (isMoreRecent(nmajor, nminor, nlevel, major, minor, level)) {
		NSLog(@"newer release %d.%d.%d is available\n", nmajor, nminor, nlevel);
		NSArray *histoChange=[properties valueForKeyPath:@"history"];
		int i, count = [histoChange count];
		[history release];
		history=[[NSMutableArray arrayWithCapacity:count]retain];
		for (i = 0; i < count; i++) {
			NSDictionary *d = [histoChange objectAtIndex:i];
			NSString *v=[d objectForKey:@"version"];
			if ([v isEqualToString:curVersion]) break;
			[history addObject:d];
		}
		NSNib *nib=[[NSNib alloc] initWithNibNamed:@"SoftwareUpdate" bundle:mb];
		BOOL ok=[nib instantiateNibWithOwner:self topLevelObjects:nil];
		if (!ok) NSLog(@"failed loading SoftwareUpdate\n");
	}

}

- (IBAction) gotoSite:(id)sender;
{
	NSString *urls=[properties valueForKeyPath:@"softwareUrl"];
	if (!urls) return;
	[[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString:urls]];
}
- (IBAction) getSoftware:(id)sender
{
	NSString *urls=[properties valueForKeyPath:@"downloadUrl"];
	if (!urls) return;
	[[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString:urls]];
}



#pragma mark -
#pragma mark *** NSURLConnection delegate ***

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	[receivedData setLength:0];
	if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
		NSHTTPURLResponse *r=(NSHTTPURLResponse *)response;
		int code=[r statusCode];
		NSDictionary *d=[r allHeaderFields];
		if (code != 200) {
			NSLog(@"got response %d h:%@\n", code, d);
		}
	}
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	//printf("data for  url %s, %d bytes\n", [[_url absoluteString] UTF8String], [data length]);
	// append the new data to the receivedData
	[receivedData appendData:data];
}
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	// release the connection, and the data object
	NSLog(@"error for connection(%@)\n", error);
	NSAssert(connection == cnx, @"not current cnx");
	[cnx release];
	cnx=nil;
	[receivedData setLength:0];
	
	// inform the user
	NSLog(@"Connection failed! Error - %d %@ %@ %@\nfailure reason: %@\nrecovery: %@\n",
	      [error code], [error domain],
	      [error localizedDescription],
	      [[error userInfo] objectForKey:NSErrorFailingURLStringKey],
	      [error localizedFailureReason], [error localizedRecoverySuggestion]);
}
-(NSCachedURLResponse *)connection:(NSURLConnection *)connection
                 willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
	return nil;
}


- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	if (0!=[receivedData length]) {
		[cnx release]; cnx=nil;
		[self performSelector:@selector( loadSuccess: )
			   withObject:receivedData
			   afterDelay:0.0];
	} else {
		[cnx release]; cnx=nil;
	}
}

@end
