//
//  InCallPopup.m
//  sipPhone
//
//  Created by Daniel Braun on 14/11/07.
//  Copyright 2007 Daniel Braun. All rights reserved.
//

#import "InCallPopup.h"


@implementation InCallPopup
- (void)setImage:(NSImage *)image;
{
	_image = [image retain];
	[self setNeedsDisplay:YES];
}

- (void) dealloc
{
	[_image release];
	[super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil) {
		_image=[[NSImage imageNamed:@"incallbg"]retain];
	}
	return self;
}

- (void)drawRect:(NSRect)rect
{
	[[NSColor clearColor] set];
	NSRectFill([self frame]);
	[_image compositeToPoint:NSZeroPoint operation:NSCompositeSourceOver];
	
}


@end
