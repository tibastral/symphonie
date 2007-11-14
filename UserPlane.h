//
//  UserPlane.h
//  sipPhone
//
//  Created by Daniel Braun on 21/10/07.
//  Copyright 2007 Daniel Braun. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "pjmedia.h"

@class QTMovie;

@interface UserPlane : NSObject {
	pj_pool_t *pool;
	pjmedia_endpt *med_endpt;
	pj_caching_pool cp;

	pjmedia_snd_port *inputOutput;	// speaker output
	//pjmedia_snd_port *input;	// mic input
	pjmedia_port *tone_generator;
	
	pjmedia_transport  *rtp_transport;
	pjmedia_session    *rtp_session;
	
	int outputDevIdx;
	int inputDevIdx;
	float normalOutputVolume;
	float normalInputGain;
	BOOL hogged;
	
	QTMovie *ringSequence;
}


- (void) _initMedia;


- (void) endUserPlane;
- (void) startUserPlane;

- (void) startRing;
- (void) stopRing;


- (void) localTone:(int) tone;
- (void) sendDtmf:(NSString *)digits;

- (NSString *) setupAndGetLocalSdp;
- (BOOL) setupWithtLocalSdp:(NSString *)local remoteSdp:(NSString *)remote outCall:(BOOL)outCall negociatedLocal:(NSString **)pNL;

@end
