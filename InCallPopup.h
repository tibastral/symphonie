//
//  InCallPopup.h
//  sipPhone
//
//  Created by Daniel Braun on 14/11/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface InCallPopup : NSView {
	NSImage* _image;
}
- (void)setImage:(NSImage *)image;

@end
