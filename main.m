//
//  main.m
//  symPhonie
//
//  Created by Daniel Braun on 20/10/07.
//  Copyright Daniel Braun 2007. All rights reserved.
//

#import <Cocoa/Cocoa.h>
//#import "MiscDebug.h"
int main(int argc, char *argv[])
{
#if 0	
	if (0) {
		NSAutoreleasePool *pool=[[NSAutoreleasePool alloc]init];
		UKCrashReporterCheckForCrash();
		[pool release];
	}
	if (1) {
		[XMenuItem initialize];
	}
#endif
	return NSApplicationMain(argc,  (const char **) argv);
}
