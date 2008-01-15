//
//  UserPlane.m
//  symPhonie
//
//  Created by Daniel Braun on 21/10/07.
//  Copyright 2007 Daniel Braun. All rights reserved.
//

#import "UserPlane.h"
#import "Properties.h"

#include <AudioUnit/AudioUnit.h>
#include <CoreAudio/CoreAudio.h>
#include <AudioToolbox/AudioToolbox.h>
#import <QTKit/QTMovie.h>

#import "pj/assert.h"

@implementation UserPlane

#define SAMPLES_PER_FRAME 160

static int _debugAudio=0;

static UserPlane *aUp=nil;
// pj_assert changed so it goes here
void _externalAssert(int l, char *f, char *e)
{
	NSLog(@"pj assertion failuer in %s:%d expr: %s\n", f, l, e);
	[aUp pjassertfailed];
}

- (void) pjassertfailed
{
	NSAssert(0, @"pjassert failed\n");
}
- (id) init {
	self = [super init];
	if (self != nil) {
		if (!aUp) aUp=self;
		[self _initMedia];
		outputDevIdx=-1;
		inputDevIdx=-1;
	}
	
	return self;
}

- (void) dealloc {
	if (recordBuffer) NSZoneFree(NSDefaultMallocZone(), recordBuffer); recordBuffer=NULL;
	if (tone_generator) pjmedia_port_destroy(tone_generator);
	if (capturePort) pjmedia_port_destroy(capturePort);
	if (playbackPort) pjmedia_port_destroy(playbackPort);
	if (inputOutput) pjmedia_snd_port_destroy(inputOutput);
	if (confbridge) pjmedia_conf_destroy(confbridge);

	[ringSequence release];
	[audioTestHelper release];
	[super dealloc];
}

static const pjmedia_tone_desc _tones[]={
	{220, 0, 300, 0},
	{440, 0, 300, 0},
	{880, 440, 300, 100}
};

extern AudioDeviceID *_GlobMacDevIds;

static int hasProperty(AudioDeviceID dev, UInt32 inChannel,
	    int inSection,
	    AudioHardwarePropertyID inPropertyID) 
{
	UInt32 siz;
	Boolean w;
	OSStatus theError = AudioDeviceGetPropertyInfo(dev,
				inChannel, inSection, inPropertyID, &siz, &w);
	return theError == 0;
}

static int hasWProperty(AudioDeviceID dev, UInt32 inChannel,
		   int inSection,
		   AudioHardwarePropertyID inPropertyID) 
{
	Boolean writable=0;
	OSStatus theError = AudioDeviceGetPropertyInfo(dev,
						       inChannel, inSection, 
						       inPropertyID, NULL, &writable);
	if (theError) return 0;
	if (!writable) return 0;
	return 1;
}

static float getVolume(AudioDeviceID dev, int isInput)
{
	//AudioDeviceID outputDevice;
	//UInt32 size=sizeof(outputDevice);

	UInt32 propSize=0;
	OSStatus ss=AudioDeviceGetPropertyInfo(dev, 0, isInput, kAudioDevicePropertyDeviceName, &propSize, NULL);
	if (_debugAudio) NSLog(@"dev name size %d, rc=%d\n", propSize, ss);
	float vol=0.0;
	UInt32 s=sizeof(vol);
	if (hasProperty(dev, 0, isInput, kAudioDevicePropertyVolumeDecibels)) {
		AudioDeviceGetProperty(dev,0,isInput,kAudioDevicePropertyVolumeDecibels,
				       &s ,(void*)&vol);
	} else if (hasProperty(dev, 1, isInput, kAudioDevicePropertyVolumeDecibels)) {
			AudioDeviceGetProperty(dev,1,isInput,kAudioDevicePropertyVolumeDecibels,
					       &s ,(void*)&vol);
	}
	if (_debugAudio) NSLog(@"got volume %g\n", vol);
	return vol;
}
static void setVolume(AudioDeviceID dev,int isInput, float v)
{
	if (hasWProperty(dev, 0, isInput, kAudioDevicePropertyVolumeScalar)) {
		AudioDeviceSetProperty(dev,NULL, 0,isInput,kAudioDevicePropertyVolumeDecibels,
			       sizeof(v) , (void*)&v);
	} else {
		if (hasWProperty(dev, 1,isInput, kAudioDevicePropertyVolumeScalar)) {
			AudioDeviceSetProperty(dev,NULL, 1,isInput,kAudioDevicePropertyVolumeDecibels,
					       sizeof(v) , (void*)&v);
		}
		if (hasWProperty(dev, 2, isInput, kAudioDevicePropertyVolumeScalar)) {
				AudioDeviceSetProperty(dev,NULL, 2,isInput,kAudioDevicePropertyVolumeDecibels,
						       sizeof(v) , (void*)&v);
		}
	}
				
}

- (BOOL) setHog:(AudioDeviceID) dev input:(int)isInput value:(BOOL)hog
{
	if (!hasWProperty(dev, 0, isInput,kAudioDevicePropertyHogMode)) {
		return hogged;
	}
	pid_t hpid=(pid_t)getpid();
	if (hog) {
		if (hogged) return hogged;
		OSStatus rc=AudioDeviceSetProperty(dev, NULL, 0, isInput, kAudioDevicePropertyHogMode, sizeof(hpid), &hpid);
		if (_debugAudio) NSLog(@"hog mode on: %d / %d - rx=%X\n", (int) hpid, getpid(), rc);
		if (hpid==getpid()) {
			hogged=YES;
		}
	} else {
		if (!hogged) return hogged;
		AudioDeviceSetProperty(dev, NULL, 0, isInput, kAudioDevicePropertyHogMode, sizeof(hpid), &hpid);
		if (_debugAudio) NSLog(@"hog mode off: %d / %d\n", (int) hpid, getpid());
		if (hpid != getpid()) hogged=NO;
	}
	return hogged;
}


- (void) _needInputOutput:(BOOL)ring
{
	int rc;
	if (inputOutput) return;
	[self stopRing];

	//long vol;
	//GetDefaultOutputVolume(&vol);
	//SetDefaultOutputVolume(vol*4);
	if (!callpool) callpool = pj_pool_create( &cp.factory, "call", 4000, 4000, NULL);

#if 0
	int ndev=pjmedia_snd_get_dev_count();
	int i;
	if (0) for (i=0; i<ndev; i++) {
		const pjmedia_snd_dev_info *dinfo;
		dinfo=pjmedia_snd_get_dev_info(i);
		if (_debugAudio) NSLog(@"dev %d: %s\n", i, dinfo->name);
	}
#endif
	int ndev=pjmedia_snd_get_dev_count();
	int inputNum=getIntProp(@"selectedInputDeviceIndex", 0);
	int outputNum=getIntProp(@"selectedInputDeviceIndex", 0);
	outputDevIdx=-1;
	inputDevIdx=-1;
	int i, ni, no;
	for (i=0,ni=0,no=0; i<ndev; i++) {
		const pjmedia_snd_dev_info *dinfo;
		dinfo=pjmedia_snd_get_dev_info(i);
		if (dinfo->input_count) {
			if (ni==inputNum) inputDevIdx=i;
			ni++;
		}
		if (dinfo->output_count) {
			if (no==outputNum) outputDevIdx=i;
			no++;
		}
	}
	if (ring) {
		rc = pjmedia_snd_port_create_player(
					    callpool,                              /* pool                 */
					    &outputDevIdx,                                /* use default dev.     */
					    8000,				 /* clock rate.          */
					    1,				 /* # of channels.       */
					    SAMPLES_PER_FRAME,		 /* samples per frame.   */
					    16,   /* bits per sample.     */
					    0,                                 /* options              */
					    &inputOutput                          /* returned port        */
					    );
	} else {
		rc = pjmedia_snd_port_create(callpool,                              /* pool                 */
						    &inputDevIdx,
						    &outputDevIdx,                                /* use default dev.     */
						    8000,				 /* clock rate.          */
						    1,				 /* # of channels.       */
						    SAMPLES_PER_FRAME,		 /* samples per frame.   */
						    16,   /* bits per sample.     */
						    0,                                 /* options              */
						    &inputOutput                          /* returned port        */
						    );
	}
	NSAssert(!rc, @"pjmedia_snd_port_create failed");
	//if (_debugAudio) NSLog(@"pjmedia_snd_port_create_player devid %d\n", output->play_id);
	//PJ_DEF(const pjmedia_snd_dev_info*) pjmedia_snd_get_dev_info(unsigned index)
	//const void *info=pjmedia_snd_port_get_hwinfo(output);
	NSAssert(outputDevIdx>=0, @"bad play id");
	NSAssert(outputDevIdx<32, @"bad play id");
	if (_debugAudio) NSLog(@"using play audio id %d\n", _GlobMacDevIds[outputDevIdx]);
	
	normalOutputVolume=getVolume(_GlobMacDevIds[outputDevIdx], 0);
	
	if (getBoolProp(@"setVolume",YES)) {
		//float volume=getFloatProp(ring ? @"audioOutputVolume" : @"audioRingVolume",-8);
		float volume=getFloatProp(@"audioOutputVolume",-8);
		if (_debugAudio) NSLog(@"setting volume (%s) to %g\n", ring ? "ring":"normal", volume);
		setVolume(_GlobMacDevIds[outputDevIdx], 0, volume);
		if (!ring) {
			NSAssert(inputDevIdx>=0, @"bad rec id");
			NSAssert(inputDevIdx<32, @"bad rec id");
			normalInputGain=getVolume(_GlobMacDevIds[inputDevIdx], 1);
			double newg=getFloatProp(@"audioInputGain", 100);
			setVolume(_GlobMacDevIds[inputDevIdx], 1, newg);
			if (_debugAudio) NSLog(@"setting input gain from %g to %g\n", normalInputGain, newg);

		}

	} else {
		if (_debugAudio) NSLog(@"not setting volume (%s) to %g\n", ring ? "ring":"normal");
	}
	if (0 && getBoolProp(@"hogMode", YES)) {
		[self setHog:(AudioDeviceID) _GlobMacDevIds[outputDevIdx] input:0 value:YES];
	}
}

#if 0
- (void) _needInput
{
	int rc;
	if (input) return;
	
	inputDevIdx=-1;
	rc = pjmedia_snd_port_create_rec(
					 pool,                              /* pool                 */
					 &inputDevIdx,                                /* use default dev.     */
					 8000,				 /* clock rate.          */
					 1,				 /* # of channels.       */
					 SAMPLES_PER_FRAME,		 /* samples per frame.   */
					 16,   /* bits per sample.     */
					 0,                                 /* options              */
					 &input                          /* returned port        */
					 );
	NSAssert(!rc, @"pj_init failed");
	NSAssert(inputDevIdx>=0, @"bad play id");
	NSAssert(inputDevIdx<32, @"bad play id");
	if (_debugAudio) NSLog(@"using rec audio id %d\n", _GlobMacDevIds[inputDevIdx]);
	if (getBoolProp(@"setVolume", YES)) {
		normalInputGain=getVolume(_GlobMacDevIds[inputDevIdx], 1);
		setVolume(_GlobMacDevIds[inputDevIdx], 1, getFloatProp(@"audioInputGain",100));
	}
	
}
#endif

- (void) startRing
{
	NSString *ringPath = [[NSBundle mainBundle] pathForResource: @"Cornemuse.mid" 
						       ofType: nil];
	NSURL *ringUrl = [NSURL fileURLWithPath: ringPath];
	NSError *err=nil;
	if (ringSequence) {
		[ringSequence stop];
		[ringSequence release];
	}
	ringSequence = [[QTMovie alloc] initWithURL: ringUrl error:&err];
	[ringSequence play];
}

- (void) stopRing
{
	[ringSequence stop];
	[ringSequence release];
	ringSequence=nil;
}
- (void) _initMedia
{
	int rc;
	static int mediaInitDone=0;
	_debugAudio=getBoolProp(@"debugAudio", NO);
	if (!mediaInitDone) {
		rc= pj_init();
		NSAssert(!rc, @"pj_init failed");
		pj_log_set_level(_debugAudio ? 99: 0);
		mediaInitDone=1;
	}
	pj_caching_pool_init(&cp, &pj_pool_factory_default_policy, 0);
	
	rc = pjmedia_endpt_create(&cp.factory, NULL, 1, &med_endpt);
	NSAssert(!rc, @"pj_init failed");

	pjmedia_codec_g711_init(med_endpt);

	
	
	gpool = pj_pool_create( &cp.factory, "app", 4000, 4000, NULL);

	rc = pjmedia_tonegen_create(gpool, 8000, 1, SAMPLES_PER_FRAME, 16, 0, &tone_generator);
	NSAssert(!rc, @"pj_init failed");

	//[self _needInput];
	//[self _needOutput];
	
	NSAssert(!rc, @"pj_init failed");

	
	// 	rc = pjmedia_snd_port_connect( snd_port, port);

}

- (void) endUserPlane
{
	NSNumber *sv=getProp(@"setVolume",[NSNumber numberWithBool:YES]);
	NSAssert(sv, @"setVolume not set");
	[self setHog:(AudioDeviceID) _GlobMacDevIds[outputDevIdx] input:0 value:NO];

	if (getBoolProp(@"setVolume", YES)) {
		if (inputDevIdx>=0) setVolume(_GlobMacDevIds[inputDevIdx], 1, normalInputGain);
		if (outputDevIdx>=0) setVolume(_GlobMacDevIds[outputDevIdx], 0, normalOutputVolume);
	}
	NSAssert(tone_generator, @"nil tone gen");
	pjmedia_tonegen_stop(tone_generator);
	if (inputOutput) {
		pjmedia_snd_port_disconnect(inputOutput);
		pjmedia_snd_port_destroy(inputOutput);
		inputOutput=NULL;
	}
	if (rtp_session) {
		pjmedia_session_destroy(rtp_session);
		rtp_session=NULL;
	}
	if (confbridge) {
		pjmedia_conf_destroy(confbridge);
		confbridge=NULL;
	}
	if (rtp_transport) {
		pjmedia_transport_udp_close(rtp_transport);
		rtp_transport=NULL;
	}
	
#if 0
	if (input) {
		pjmedia_snd_port_disconnect(input);
		pjmedia_snd_port_destroy(input);
		input=NULL;
	}
#endif
	[self stopRing];
	if (callpool) pj_pool_reset(callpool);
}

- (void) startUserPlane
{
}
- (void) localTone:(int) toneNum
{
	//[self _needInput]; // debug
	[self _needInputOutput:NO];
	if ((unsigned int)toneNum>sizeof(_tones)/sizeof(pjmedia_tone_desc)) toneNum=-1;
	if (toneNum>0) {
		pjmedia_tonegen_play(tone_generator, toneNum, _tones, 1);
	} else {
		pjmedia_tonegen_stop(tone_generator);
	}
	pjmedia_snd_port_connect(inputOutput, tone_generator);

}



- (NSString *) setupAndGetLocalSdp
{
	int rc;
	unsigned short port;
	
	//const pjmedia_codec_info *codec_info;
	//pjmedia_codec_mgr_get_codec_info( pjmedia_endpt_get_codec_mgr(med_endpt),
        //                                  0, &codec_info); // xxx

	//pjmedia_stream_info info;
	//memset(&info, 0, sizeof(info));
	//info.type = PJMEDIA_TYPE_AUDIO;
	//info.dir=PJMEDIA_DIR_ENCODING_DECODING;
	//pj_memcpy(&info.fmt, codec_info, sizeof(pjmedia_codec_info));
	//info.tx_pt = codec_info->pt;
	//info.ssrc = pj_rand();
	
	if (!callpool) callpool = pj_pool_create( &cp.factory, "call", 4000, 4000, NULL);
	
	for (port=30000;  port<30100; port+=2) {
		if (_debugAudio) NSLog(@"trying port %d\n", port);
		rc=pjmedia_transport_udp_create(med_endpt, "rx", port, 0, &rtp_transport);
		if (rc) continue;
		pjmedia_transport_udp_info udp_info;
		pjmedia_transport_udp_get_info(rtp_transport, &udp_info);
		port=ntohs(udp_info.skinfo.rtp_addr_name.sin_port);
		
		pjmedia_sdp_session *local_sdp;
		rc = pjmedia_endpt_create_sdp( med_endpt,     /* the media endpt  */
			callpool,       /* pool.            */
			1,               /* # of streams     */
			&(udp_info.skinfo),   /* RTP sock info    */
			&local_sdp);     /* the SDP result   */
		NSAssert(!rc, @"create sdp failed");
		char szTmp[1024];
		rc=pjmedia_sdp_print(local_sdp, szTmp, sizeof(szTmp)-1)	;
		NSAssert(rc>0, @"faild sdp print");
		szTmp[rc]='\0';
		return [NSString stringWithCString:szTmp];
	}
	return 0;
}

- (BOOL) setupWithtLocalSdp:(NSString *)local remoteSdp:(NSString *)remote outCall:(BOOL) outCall negociatedLocal:(NSString **)pNL;
{
	pjmedia_sdp_session *local_sdp;
	pjmedia_sdp_session *remote_sdp;
	const pjmedia_sdp_session *nlocal_sdp;
	const pjmedia_sdp_session *nremote_sdp;

	int rc;
	rc=pjmedia_sdp_parse(callpool, (char *) [local cString], [local length], &local_sdp);
	NSAssert(!rc, @"failed parsing sdp");
	rc=pjmedia_sdp_parse(callpool, (char *) [remote cString], [remote length], &remote_sdp);
	NSAssert(!rc, @"failed parsing remote sdp");

	// negociate sdp
	pjmedia_sdp_neg *nego=NULL;
	if (outCall) {
		rc=pjmedia_sdp_neg_create_w_local_offer(callpool, local_sdp, &nego);
		NSAssert(!rc, @"nego failed");
		pjmedia_sdp_neg_set_prefer_remote_codec_order(nego, 0);
		pjmedia_sdp_neg_set_remote_answer(callpool, nego, remote_sdp);
	} else {
		rc=pjmedia_sdp_neg_create_w_remote_offer(callpool, local_sdp, remote_sdp, &nego);
		NSAssert(!rc, @"nego failed");
		pjmedia_sdp_neg_set_prefer_remote_codec_order(nego, 1);
		//pjmedia_sdp_neg_set_local_answer(callpool, nego, local_sdp);
	}
	rc=pjmedia_sdp_neg_negotiate(callpool, nego, 0);
	NSAssert(!rc, @"nego failed");
	rc = pjmedia_sdp_neg_get_active_remote(nego, &nremote_sdp);
	rc = pjmedia_sdp_neg_get_active_local(nego, &nlocal_sdp);
	
	
	if (pNL) {
		char szTmp[1024];
		rc=pjmedia_sdp_print(nlocal_sdp, szTmp, sizeof(szTmp)-1);
		NSAssert(rc>0, @"faild sdp print");
		szTmp[rc]='\0';
		*pNL=[NSString stringWithCString:szTmp];
	}
	
	pjmedia_session_info sess_info;

	rc = pjmedia_session_info_from_sdp(callpool, med_endpt,
					       1, &sess_info,
					       nlocal_sdp, nremote_sdp);
	NSAssert(!rc, @"failed creating SDP session info");
	rc = pjmedia_session_create(med_endpt, &sess_info,
					 &rtp_transport, NULL, &rtp_session );
	NSAssert(!rc, @"failed creating media session");

	pjmedia_port *media_port;
	pjmedia_session_get_port(rtp_session, 0, &media_port);

	[self _needInputOutput:NO];

#if 0
	rc=pjmedia_snd_port_connect(inputOutput, media_port);
#else
	if (_debugAudio) NSLog(@"conf create\n");
	rc=pjmedia_conf_create(callpool,3,8000, 1, SAMPLES_PER_FRAME,
			       16, PJMEDIA_CONF_NO_DEVICE, &confbridge);
	NSAssert(!rc, @"conf bridge create failed\n");
	pj_str_t port_name= pj_str("call");
	
	pjmedia_port *mport;
	if (_debugAudio) NSLog(@"conf get master\n");
	mport=pjmedia_conf_get_master_port(confbridge);
	if (_debugAudio) NSLog(@"pjmedia_snd_port_connect\n");
	rc=pjmedia_snd_port_connect(inputOutput, mport);
	if (_debugAudio) NSLog(@"pjmedia_snd_port_connect rc=%d\n",rc);
	if (_debugAudio) NSLog(@"add port\n");
	rc=pjmedia_conf_add_port(confbridge, callpool, media_port, &port_name, &cb_session_slot);
	if (_debugAudio) NSLog(@"add port rc=%d slot=%d\n", rc,cb_session_slot);
	pjmedia_conf_connect_port(confbridge, cb_session_slot,0, 0);
	pjmedia_conf_connect_port(confbridge, 0,cb_session_slot, 0);
	if (getBoolProp(@"txboost", YES)) pjmedia_conf_adjust_tx_level(confbridge, cb_session_slot, 512*1);
	if (1) {
		pj_str_t tport_name= pj_str("ton");
		rc=pjmedia_conf_add_port(confbridge, callpool, tone_generator, &tport_name, &cb_tone_slot);
		if (_debugAudio) NSLog(@"add tone port rc=%d slot=%d\n", rc,cb_tone_slot);
		if (0) rc=pjmedia_conf_configure_port(confbridge, cb_tone_slot, PJMEDIA_PORT_NO_CHANGE , PJMEDIA_PORT_DISABLE);

		pjmedia_conf_connect_port(confbridge, cb_tone_slot, cb_session_slot, 0);
		if (1) { // local echo
			pjmedia_conf_connect_port(confbridge, cb_tone_slot, 0, 0);
		}
	}
	
#endif
	//rc=pjmedia_snd_port_set_ec(inputOutput, pool, 20, 0);
	
	return YES;
}


- (NSArray *)  inputDeviceList
{
	int ndev=pjmedia_snd_get_dev_count();
	int i;
	NSMutableArray *res=[NSMutableArray arrayWithCapacity:3];
	if (1) for (i=0; i<ndev; i++) {
		const pjmedia_snd_dev_info *dinfo;
		dinfo=pjmedia_snd_get_dev_info(i);
		if (_debugAudio) NSLog(@"dev %d: %s\n", i, dinfo->name);
		if (dinfo->input_count) {
			[res addObject:[NSString stringWithCString:dinfo->name encoding:NSUTF8StringEncoding]];
		}
	}
	
	return res;
}


- (NSArray *)  outputDeviceList
{
	int ndev=pjmedia_snd_get_dev_count();
	int i;
	NSMutableArray *res=[NSMutableArray arrayWithCapacity:3];
	if (1) for (i=0; i<ndev; i++) {
		const pjmedia_snd_dev_info *dinfo;
		dinfo=pjmedia_snd_get_dev_info(i);
		if (_debugAudio) NSLog(@"dev %d: %s\n", i, dinfo->name);
		if (dinfo->output_count) {
			[res addObject:[NSString stringWithCString:dinfo->name encoding:NSUTF8StringEncoding]];
		}
	}
	if (0) { // for debug
		static int count=1;
		[res addObject:[NSString stringWithFormat:@"dummy%d", count++]];
	}
	return res;
}

#define RECORD_BUFFER_SIZE (2*8000*5)
- (void) _playbackEnded:(id)dummy
{
	if (_debugAudio) NSLog(@"playBackEnded\n");
	[self stopAudioTest];
}

static pj_status_t playBackEnded(pjmedia_port *port, void *usr_data)
{
	UserPlane *me=(UserPlane *)usr_data;
	[me performSelectorOnMainThread:@selector(_playbackEnded:) withObject:nil waitUntilDone:NO];
	return 0;
}

- (void) _recordEnded:(id)dummy
{
	if (!capturePort) return; // seems that pjmedia call it twice
	if (_debugAudio) NSLog(@"record ended\n");
	pjmedia_snd_port_disconnect(inputOutput);
	pjmedia_port_destroy(capturePort);
	capturePort=NULL;
	pj_status_t rc=pjmedia_mem_player_create(callpool,
						  recordBuffer,
						  RECORD_BUFFER_SIZE,
						  8000	/* clock_rate */,
						  1 	/* channel_count */,
						  SAMPLES_PER_FRAME,
						  16	/* bits_per_sample*/,
						  0	/* options*/,
						  &playbackPort);
	if (rc) {
		[self stopAudioTest];
		return;
	}
	rc=pjmedia_mem_player_set_eof_cb(playbackPort, (void *)self, playBackEnded);
	if (rc) {
		[self stopAudioTest];
		return;
	}
	rc=pjmedia_snd_port_connect(inputOutput, playbackPort);
	if (rc) {
		[self stopAudioTest];
		return;
	}
	[audioTestHelper audioTestPlaying];
}

static pj_status_t recordEnded(pjmedia_port *port, void *usr_data)
{
	UserPlane *me=(UserPlane *)usr_data;
	[me performSelectorOnMainThread:@selector(_recordEnded:) withObject:nil waitUntilDone:NO];
	return 0;
}
- (void) startAudioTestWith:(id) helper
{
	if (capturePort || playbackPort) return;
	[self _needInputOutput:NO];
	recordBuffer=NSZoneMalloc(NSDefaultMallocZone(), RECORD_BUFFER_SIZE);
	pj_status_t rc=pjmedia_mem_capture_create(callpool,
					 recordBuffer,
					 RECORD_BUFFER_SIZE,
					 8000	/* clock_rate */,
					 1 	/* channel_count */,
					 SAMPLES_PER_FRAME,
					 16	/* bits_per_sample*/,
					 0	/* options*/,
					 &capturePort);
	if (rc) {
		NSZoneFree(NSDefaultMallocZone(), recordBuffer); recordBuffer=NULL;
		return;
	}
	NSAssert(!audioTestHelper, @"audioTestHelper should be nil");
	audioTestHelper=[helper retain];
	rc=pjmedia_mem_capture_set_eof_cb(capturePort, (void *)self, recordEnded);
	if (rc) {
		[self stopAudioTest];
		return;
	}
	rc=pjmedia_snd_port_connect(inputOutput, capturePort);
	if (rc) {
		[self stopAudioTest];
		return;
	}
	[audioTestHelper audioTestRecoding];
}

- (void) stopAudioTest
{
	if (capturePort) pjmedia_port_destroy(capturePort);
	if (playbackPort) pjmedia_port_destroy(playbackPort);
	capturePort=NULL;
	playbackPort=NULL;
	if (recordBuffer) NSZoneFree(NSDefaultMallocZone(), recordBuffer); 
	recordBuffer=NULL;
	[audioTestHelper audioTestEnded];
	[audioTestHelper release];
	audioTestHelper=nil;
	[self endUserPlane];
}

- (void) dtmf:(NSString *)dtmf
{
	pj_str_t pdigits= pj_str( ( char *) [dtmf cString]);

	pj_status_t rc=pjmedia_session_dial_dtmf(rtp_session,0, &pdigits);
	if (_debugAudio) NSLog(@"dial dtfm rc=0x%X\n", rc);
	if (rc==PJMEDIA_RTP_EREMNORFC2833) {
		pjmedia_tone_digit digits[1]={{'1', 300,100}};
		digits[0].digit=[dtmf characterAtIndex:0];
		NSAssert(tone_generator, @"nil tone gen");
		pjmedia_tonegen_stop(tone_generator);
		pj_status_t rc=pjmedia_tonegen_play_digits(tone_generator ,1, digits,0);
		if (_debugAudio) NSLog(@"play digit rc=0x%X\n", rc);
		//pjmedia_con
	}
#if 0
						   pjmedia_tonegen_play(tone_generator, toneNum, _tones, 1);
						   } else {
						   pjmedia_tonegen_stop(tone_generator);
						   }
						   pjmedia_snd_port_connect(inputOutput, tone_generator);
#endif
}

@end
