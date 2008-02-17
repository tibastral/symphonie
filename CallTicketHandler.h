//
//  CallTicketHandler.h
//  symPhonie
//
//  Created by Daniel Braun on 16/11/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

enum callDir {
	calldirUndef=0,
	calldirIn,
	calldirOut
};
	
@class SipPhone;
@interface CallTicketHandler : NSObject {
	IBOutlet NSArrayController *historyController;
	IBOutlet SipPhone *phone;
	NSString *number;
	NSString *name;
	NSDate *startCall;
	NSDate *startOnline;
	enum callDir callDir;
	NSIndexSet *selectedEntries;
}
//- (void) addToHistoryEvent:(NSString *)event forNum:(NSString *)num duration:(NSTimeInterval)dur;

- (IBAction) testEntry:(id)sender;

- (void) setForeignNum:(NSString *) number;
- (void) setForeignName:(NSString *) aName;
- (void) tickStartInRing;
- (void) tickStartOutCall;
- (void) tickOnline;
- (void) tickHangupCause:(int) cause info:(NSString *)info;

- (void) setSelectedEntries:(NSIndexSet *)si;
@end
