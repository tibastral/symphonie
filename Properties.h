/*
 *  Properties.h
 *  CocoaMoney
 *
 *  Created by Daniel Braun on 02/11/06.
 *  Copyright 2006 Daniel Braun http://braun.daniel.free.fr. All rights reserved.
 *
 */


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
static inline float getFloatProp(NSString *k, float defaultValue)
{
	return [getProp(k, [NSNumber numberWithFloat:defaultValue]) floatValue];
}
static inline int getIntProp(NSString *k, int defaultValue)
{
	return [getProp(k, [NSNumber numberWithInt:defaultValue]) intValue];
}

static inline void setProp(NSString *k, id v)
{
	id pref=[[NSUserDefaultsController sharedUserDefaultsController] values];
	[pref setValue:v forKey:k];
}

static inline void saveProp(void)
{
	//[[NSUserDefaultsController sharedUserDefaultsController] save:nil];
}
