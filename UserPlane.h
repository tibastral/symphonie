//
//  UserPlane.h
//  symPhonie
//
//  Created by Daniel Braun on 21/10/07.
//  Copyright 2007 Daniel Braun. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "pjmedia.h"

@class QTMovie;

@protocol AudioTestHelper
- (void) audioTestRecoding;
- (void) audioTestPlaying;
- (void) audioTestEnded;
@end


@interface UserPlane : NSObject {
	pj_pool_t *gpool;
	pj_pool_t *callpool;
	pjmedia_endpt *med_endpt;
	pj_caching_pool cp;

	pjmedia_snd_port *inputOutput;	// speaker output
	//pjmedia_snd_port *input;	// mic input
	pjmedia_port *tone_generator;
	
	pjmedia_transport  *rtp_transport;
	pjmedia_session    *rtp_session;
	pjmedia_port	   *capturePort; // for audio test
	pjmedia_port	   *playbackPort;
	unsigned char	   *recordBuffer;
	//pjmedia_port	   *tonegen;
	//pjsua_conf_port_id toneslot;
	pjmedia_conf	   *confbridge;
	unsigned int	   cb_session_slot;
	unsigned int	   cb_tone_slot;

	NSObject <AudioTestHelper> *audioTestHelper;

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

- (NSString *) setupAndGetLocalSdp;
- (BOOL) setupWithtLocalSdp:(NSString *)local remoteSdp:(NSString *)remote outCall:(BOOL)outCall negociatedLocal:(NSString **)pNL;

- (NSArray *)  inputDeviceList;
- (NSArray *)  outputDeviceList;

- (void) startAudioTestWith:(id) helper;
- (void) stopAudioTest;

- (void) dtmf:(NSString *)dtmf;

@end
