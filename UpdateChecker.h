//
//  UpdateChecker.h
//  sipPhone
//
//  Created by Daniel Braun on 16/02/08.
//  Copyright 2008 Daniel Braun. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface UpdateChecker : NSObject {
	NSURLConnection *cnx;
	NSMutableData *receivedData;
	NSDictionary *properties;
	NSMutableArray *history;
	NSString *appName;
	NSString *latestVersion;
	
	IBOutlet NSWindow *updateWindow;
}

- (void) getUpdateInfos;

- (IBAction) getSoftware:(id)sender;
- (IBAction) gotoSite:(id)sender;

@end
