//
//  BundledScript.m
//  tjp_helper
//
//  Created by Daniel Braun on 28/01/07.
//  Copyright 2007 Daniel Braun http://braun.daniel.free.fr. All rights reserved.
//

#import "BundledScript.h"
#import <Carbon/Carbon.h>

@interface NSAppleEventDescriptor (NDAppleScriptObject)
+ (id)descriptorWithObject:(id)anObject;
+ (id)descriptorWithNumber:(NSNumber *)aNumber;
+ (id)descriptorWithArray:(NSArray *)anArray ;
+ (id)descriptorWithDictionary:(NSDictionary *)aDictionary;

@end

@implementation NSAppleEventDescriptor (NDAppleScriptObject)

+ (id)descriptorWithNumber:(NSNumber *)aNumber {
	const char *theType = [aNumber objCType];
	NSAppleEventDescriptor *theDescriptor = nil;
	unsigned int theIndex;
	
	struct {
		char *objCType;
		DescType descType;
		unsigned short	size;
	}
	
	theTypes[] = {
	{ @encode(float), typeIEEE32BitFloatingPoint, sizeof(float) },
	{ @encode(double), typeIEEE64BitFloatingPoint, sizeof(double) },
	{ @encode(unsigned char), typeUInt32, sizeof(unsigned char) },
	{ @encode(char), typeSInt16, sizeof(char) },
	{ @encode(unsigned short int), typeUInt32, sizeof(unsigned short int) },
	{ @encode(short int), typeSInt16, sizeof(short int) },
	{ @encode(unsigned int), typeUInt32, sizeof(unsigned int) },
	{ @encode(int), typeSInt32, sizeof(int) },
	{ @encode(unsigned long int), typeUInt32, sizeof(unsigned long int) },
	{ @encode(long int), typeSInt32, sizeof(long int) },
	{ @encode(unsigned long long), typeSInt64, sizeof(unsigned long long) },
	{ @encode(long long), typeSInt64, sizeof(long long) },
	{ @encode(BOOL), typeBoolean, sizeof(BOOL) },
	{ NULL, 0, 0 }
	};
	
	for(theIndex = 0; theDescriptor == nil && theTypes[theIndex].objCType != NULL; theIndex++) {
		if(strcmp(theTypes[theIndex].objCType, theType) == 0) {
			char *theBuffer[64];
			[aNumber getValue:theBuffer];
			theDescriptor = [self descriptorWithDescriptorType:theTypes[theIndex].descType bytes:theBuffer length:theTypes[theIndex].size];
		}
	}
	
	return theDescriptor;
}

+ (id)descriptorWithArray:(NSArray *)anArray {
	NSAppleEventDescriptor *theEventList = nil;
	unsigned int theNumOfParam = [anArray count];
	unsigned int theIndex;
	
	if(theNumOfParam > 0) {
		theEventList = [self listDescriptor];
		
		for(theIndex = 0; theIndex < theNumOfParam; theIndex++) {
			[theEventList insertDescriptor:[self descriptorWithObject:[anArray objectAtIndex:theIndex]] atIndex:theIndex+1];
		}
	}
	
	return theEventList;
}

+ (NSAppleEventDescriptor *)userRecordDescriptorWithDictionary:(NSDictionary *)aDictionary {
	NSAppleEventDescriptor *theUserRecord = nil;
	
	if([aDictionary count] > 0 && (theUserRecord = [self listDescriptor]) != nil) {
		NSEnumerator *theEnumerator = [aDictionary keyEnumerator];
		id theKey;
		unsigned int theIndex = 1;
		
		while ((theKey = [theEnumerator nextObject]) != nil) {
			[theUserRecord insertDescriptor:[NSAppleEventDescriptor descriptorWithString:[theKey description]] atIndex:theIndex++];
			[theUserRecord insertDescriptor:[NSAppleEventDescriptor descriptorWithObject:[aDictionary objectForKey:theKey]] atIndex:theIndex++];
		}
	}
	
	return theUserRecord;
}
+ (id)descriptorWithDictionary:(NSDictionary *)aDictionary {
	NSAppleEventDescriptor *theRecordDescriptor = [self recordDescriptor];
	[theRecordDescriptor setDescriptor:[NSAppleEventDescriptor userRecordDescriptorWithDictionary:aDictionary] forKeyword:keyASUserRecordFields];
	return theRecordDescriptor;
}

+ (id)descriptorWithObject:(id)anObject
{
	NSAppleEventDescriptor *theDescriptor = nil;
	
	if(anObject == nil || [anObject isKindOfClass:[NSNull class]]) {
		theDescriptor = [NSAppleEventDescriptor nullDescriptor];
	} else if([anObject isKindOfClass:[NSNumber class]]) {
		theDescriptor = [self descriptorWithNumber:anObject];
	} else if([anObject isKindOfClass:[NSString class]]) {
		theDescriptor = [self descriptorWithString:anObject];
	} else if([anObject isKindOfClass:[NSArray class]]) {
		theDescriptor = [self descriptorWithArray:anObject];
	} else if([anObject isKindOfClass:[NSDictionary class]]) {
		theDescriptor = [self descriptorWithDictionary:anObject];
	} else if([anObject isKindOfClass:[NSDate class]]) {
		LongDateTime ldt;
		UCConvertCFAbsoluteTimeToLongDateTime(CFDateGetAbsoluteTime((CFDateRef)anObject), &ldt);
		theDescriptor = [NSAppleEventDescriptor descriptorWithDescriptorType:typeLongDateTime bytes:&ldt length:sizeof(ldt)];
	} else if([anObject isKindOfClass:[NSAppleEventDescriptor class]]) {
		theDescriptor = anObject;
	} else if([anObject isKindOfClass:NSClassFromString(@"NDAppleScriptObject")]) {
		theDescriptor = [self performSelector:NSSelectorFromString(@"descriptorWithAppleScript:") withObject:anObject];
	} else if([anObject isKindOfClass:[NSScriptObjectSpecifier class]]) {
		theDescriptor = [anObject _asDescriptor];
	} else if([anObject respondsToSelector:@selector(objectSpecifier)]) {
		theDescriptor = [[anObject objectSpecifier] _asDescriptor];
	}
	
	return theDescriptor;
}

@end
@implementation BundledScript

- (id) init {
	self = [super init];
	if (self != nil) {
		//<#initializations#>
	}
	return self;
}

- (void) dealloc {
	[appleScript release];
	[super dealloc];
}

+ (BundledScript *) bundledScript:(NSString *) scriptName
{
	id s=[[[self class]alloc] initWithScript:scriptName];
	return [s autorelease];
}

- (void) handleError:(NSString *)err
{
	NSLog(@"Error %@\n", err);
}

- (id) runEvent:(NSString *)procedureName withArgs:(id) arg1, ...
{
	int i;
	va_list argumentList;
	NSAppleEventDescriptor* parameters = [NSAppleEventDescriptor listDescriptor];
	id arg;
	va_start(argumentList, arg1);          // Start scanning for arguments after firstObject.
	for (i=1,arg=arg1; arg; ) {
		// process arg
		NSAppleEventDescriptor *par;
		//par=[NSAppleEventDescriptor descriptorWithString:arg];
		par=[NSAppleEventDescriptor descriptorWithObject:arg];
		[parameters insertDescriptor:par atIndex:i];
		i++;

		// next arg, until nil
		arg=va_arg(argumentList, id);
	}
	va_end(argumentList);
	
	// create the AppleEvent target
	ProcessSerialNumber psn = {0, kCurrentProcess};
	NSAppleEventDescriptor* target =
		[NSAppleEventDescriptor
                        descriptorWithDescriptorType:typeProcessSerialNumber
					       bytes:&psn
					      length:sizeof(ProcessSerialNumber)];
	
	// create an NSAppleEventDescriptor with the script's method name to call,
	// this is used for the script statement: "on show_message(user_message)"
	// Note that the routine name must be in lower case.
	NSAppleEventDescriptor* handler =
		[NSAppleEventDescriptor descriptorWithString:
			[procedureName lowercaseString]];
	
	// create the event for an AppleScript subroutine,
	// set the method name and the list of parameters
	NSAppleEventDescriptor* event =
		[NSAppleEventDescriptor appleEventWithEventClass:kASAppleScriptSuite
							 eventID:kASSubroutineEvent
						targetDescriptor:target
							returnID:kAutoGenerateReturnID
						   transactionID:kAnyTransactionID];
	[event setParamDescriptor:handler forKeyword:keyASSubroutineName];
	[event setParamDescriptor:parameters forKeyword:keyDirectObject];
	
	// call the event in AppleScript
	NSDictionary* errors = [NSDictionary dictionary];
	//NSLog(@"run script\n");
	NSAppleEventDescriptor* returnDescriptor=[appleScript executeAppleEvent:event error:&errors];
	//NSLog(@"done script\n");
	if (!returnDescriptor) {
		// report any errors from 'errors'
		NSLog(@"Error %@ occured the %@ call: %@",
		      [errors objectForKey:NSAppleScriptErrorNumber],
		      procedureName,
		      [errors objectForKey:NSAppleScriptErrorBriefMessage]);
		[self handleError:@"execution failed"];
		return nil;
	}
	//NSLog(@"raise up\n");
	//NSWindow *mywin=[[NSApplication sharedApplication] mainWindow];
	//[mywin makeKeyAndOrderFront:self];
	//BOOL ac=[[NSApplication sharedApplication] isActive];
	
	//[[NSApplication sharedApplication]activateIgnoringOtherApps:YES];
	
	return @"";
}


- (id) initWithScript:(NSString *) scriptName
{
	self=[super init];
	if (!self) return self;
	
	// load the script from a resource by fetching its URL from within our bundle
	NSString* path = [[NSBundle mainBundle] pathForResource:scriptName ofType:@"scpt"];
	if (!path) path = [[NSBundle mainBundle] pathForResource:scriptName ofType:@"applescript"];
	if (!path) path = [[NSBundle mainBundle] pathForResource:scriptName ofType:nil];

	if (!path) {
		[self handleError:@"script not found"];
		return nil;
	}
	
	NSURL* url = [NSURL fileURLWithPath:path];
	if (!url) {
		[self handleError:@"cant get url"];
		return nil;
	}
	NSDictionary* errors = [NSDictionary dictionary];
	appleScript =[[NSAppleScript alloc] initWithContentsOfURL:url error:&errors];
	if (!appleScript) {
		[self handleError:@"cannot instanciate script"];
		return nil;
	}
	return self;
}
@end
