//
//  BundledScript.h
//  tjp_helper
//
//  Created by Daniel Braun on 28/01/07.
//  Copyright 2007 Daniel Braun http://braun.daniel.free.fr. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/*
 * runs an apple script located in bundle
 * contains several tools to facilitate applescript integration
 */

@interface BundledScript : NSObject {
	NSAppleScript* appleScript;
}

+ (BundledScript *) bundledScript:(NSString *) scriptName;
- (id) initWithScript:(NSString *) scriptName;
- (id) runEvent:(NSString *)procedureName withArgs:(id) arg1, ...;

@end
