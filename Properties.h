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

static inline void setProp(NSString *k, id v)
{
	id pref=[[NSUserDefaultsController sharedUserDefaultsController] values];
	[pref setValue:v forKey:k];
}

static inline void saveProp(void)
{
	//[[NSUserDefaultsController sharedUserDefaultsController] save:nil];
}
