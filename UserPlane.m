//
//  UserPlane.m
//  sipPhone
//
//  Created by Daniel Braun on 21/10/07.
//  Copyright 2007 Daniel Braun. All rights reserved.
//

#import "UserPlane.h"


@implementation UserPlane

#define SAMPLES_PER_FRAME 160

- (id) init {
	self = [super init];
	if (self != nil) {
		[self _initMedia];
	}
	return self;
}
- (void) dealloc {
	//<#deallocations#>
	[super dealloc];
}

static const pjmedia_tone_desc _tones[]={
	{220, 0, 300, 0},
	{440, 0, 300, 0},
	{880, 440, 300, 100}
};


- (void) _needOutput
{
	int rc;
	if (output) return;
	
	rc = pjmedia_snd_port_create_player(
					    pool,                              /* pool                 */
					    -1,                                /* use default dev.     */
					    8000,				 /* clock rate.          */
					    1,				 /* # of channels.       */
					    SAMPLES_PER_FRAME,		 /* samples per frame.   */
					    16,   /* bits per sample.     */
					    0,                                 /* options              */
					    &output                          /* returned port        */
					    );
	NSAssert(!rc, @"pj_init failed");
}

- (void) _needInput
{
	int rc;
	if (input) return;
	rc = pjmedia_snd_port_create_rec(
					 pool,                              /* pool                 */
					 -1,                                /* use default dev.     */
					 8000,				 /* clock rate.          */
					 1,				 /* # of channels.       */
					 SAMPLES_PER_FRAME,		 /* samples per frame.   */
					 16,   /* bits per sample.     */
					 0,                                 /* options              */
					 &input                          /* returned port        */
					 );
	NSAssert(!rc, @"pj_init failed");
}

- (void) _initMedia
{
	int rc;
	static int mediaInitDone=0;
	if (!mediaInitDone) {
		rc= pj_init();
		NSAssert(!rc, @"pj_init failed");
		pj_log_set_level(1);
		mediaInitDone=1;
	}
	pj_caching_pool_init(&cp, &pj_pool_factory_default_policy, 0);
	
	rc = pjmedia_endpt_create(&cp.factory, NULL, 1, &med_endpt);
	NSAssert(!rc, @"pj_init failed");

	pjmedia_codec_g711_init(med_endpt);

	
	
	pool = pj_pool_create( &cp.factory, "app", 4000, 4000, NULL);

	rc = pjmedia_tonegen_create(pool, 8000, 1, SAMPLES_PER_FRAME, 16, 0, &tone_generator);
	NSAssert(!rc, @"pj_init failed");

	//[self _needInput];
	//[self _needOutput];
	
	NSAssert(!rc, @"pj_init failed");

	
	// 	rc = pjmedia_snd_port_connect( snd_port, port);

}

- (void) endUserPlane
{
	pjmedia_tonegen_stop(tone_generator);
	if (output) {
		pjmedia_snd_port_disconnect(output);
		pjmedia_snd_port_destroy(output);
		output=NULL;
	}
	if (input) {
		pjmedia_snd_port_disconnect(input);
		pjmedia_snd_port_destroy(input);
		input=NULL;
	}
}

- (void) startUserPlane
{
}
- (void) localTone:(int) toneNum
{
	[self _needOutput];
	if (toneNum>sizeof(_tones)/sizeof(pjmedia_tone_desc)) toneNum=-1;
	if (toneNum>0) {
		pjmedia_tonegen_play(tone_generator, toneNum, _tones, 1);
	} else {
		pjmedia_tonegen_stop(tone_generator);
	}
	pjmedia_snd_port_connect(output, tone_generator);

}
- (void) sendDtmf:(NSString *)digits
{
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
	
	for (port=30000;  port<30100; port+=2) {
		NSLog(@"trying port %d\n", port);
		rc=pjmedia_transport_udp_create(med_endpt, "rx", port, 0, &rtp_transport);
		if (rc) continue;
		pjmedia_transport_udp_info udp_info;
		pjmedia_transport_udp_get_info(rtp_transport, &udp_info);
		port=ntohs(udp_info.skinfo.rtp_addr_name.sin_port);
		
		pjmedia_sdp_session *local_sdp;
		rc = pjmedia_endpt_create_sdp( med_endpt,     /* the media endpt  */
			pool,       /* pool.            */
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
	rc=pjmedia_sdp_parse(pool, (char *) [local cString], [local length], &local_sdp);
	NSAssert(!rc, @"failed parsing sdp");
	rc=pjmedia_sdp_parse(pool, (char *) [remote cString], [remote length], &remote_sdp);
	NSAssert(!rc, @"failed parsing remote sdp");

	// negociate sdp
	pjmedia_sdp_neg *nego;
	if (outCall) {
		rc=pjmedia_sdp_neg_create_w_local_offer(pool, local_sdp, &nego);
		NSAssert(!rc, @"nego failed");
		pjmedia_sdp_neg_set_prefer_remote_codec_order(nego, 0);
		pjmedia_sdp_neg_set_remote_answer(pool, nego, remote_sdp);
	} else {
		rc=pjmedia_sdp_neg_create_w_remote_offer(pool, local_sdp, remote_sdp, &nego);
		NSAssert(!rc, @"nego failed");
		pjmedia_sdp_neg_set_prefer_remote_codec_order(nego, 1);
		//pjmedia_sdp_neg_set_local_answer(pool, nego, local_sdp);
	}
	rc=pjmedia_sdp_neg_negotiate(pool, nego, 0);
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

	rc = pjmedia_session_info_from_sdp(pool, med_endpt,
					       1, &sess_info,
					       nlocal_sdp, nremote_sdp);
	NSAssert(!rc, @"failed creating SDP session info");
	rc = pjmedia_session_create(med_endpt, &sess_info,
					 &rtp_transport, NULL, &rtp_session );
	NSAssert(!rc, @"failed creating media session");

	pjmedia_port *media_port;
	pjmedia_session_get_port(rtp_session, 0, &media_port);

	[self _needInput];
	[self _needOutput];
	rc=pjmedia_snd_port_connect(output, media_port);
	rc=pjmedia_snd_port_connect(input, media_port);
	return YES;
}
@end
