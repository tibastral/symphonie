//
//  CallTicketHandler.h
//  sipPhone
//
//  Created by Daniel Braun on 16/11/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface CallTicketHandler : NSObject {
	IBOutlet NSArrayController *historyController;

}
- (void) addToHistoryEvent:(NSString *)event forNum:(NSString *)num duration:(NSTimeInterval)dur;

- (IBAction) testEntry:(id)sender;

@end
