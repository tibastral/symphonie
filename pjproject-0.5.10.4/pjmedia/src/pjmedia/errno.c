/* $Id: errno.c 974 2007-02-19 01:13:53Z bennylp $ */
/* 
 * Copyright (C) 2003-2007 Benny Prijono <benny@prijono.org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA 
 */
#include <pjmedia/errno.h>
#include <pjmedia/types.h>
#include <pj/string.h>
#include <portaudio.h>



/* PJMEDIA's own error codes/messages 
 * MUST KEEP THIS ARRAY SORTED!!
 * Message must be limited to 64 chars!
 */

#if defined(PJ_HAS_ERROR_STRING) && (PJ_HAS_ERROR_STRING != 0)

static const struct 
{
    int code;
    const char *msg;
} err_str[] = 
{
    /* Generic PJMEDIA errors, shouldn't be used! */
    PJ_BUILD_ERR( PJMEDIA_ERROR,	    "Unspecified PJMEDIA error" ),

    /* SDP error. */
    PJ_BUILD_ERR( PJMEDIA_SDP_EINSDP,	    "Invalid SDP descriptor" ),
    PJ_BUILD_ERR( PJMEDIA_SDP_EINVER,	    "Invalid SDP version line" ),
    PJ_BUILD_ERR( PJMEDIA_SDP_EINORIGIN,    "Invalid SDP origin line" ),
    PJ_BUILD_ERR( PJMEDIA_SDP_EINTIME,	    "Invalid SDP time line"),
    PJ_BUILD_ERR( PJMEDIA_SDP_EINNAME,	    "SDP name/subject line is empty"),
    PJ_BUILD_ERR( PJMEDIA_SDP_EINCONN,	    "Invalid SDP connection line"),
    PJ_BUILD_ERR( PJMEDIA_SDP_EMISSINGCONN, "Missing SDP connection info line"),
    PJ_BUILD_ERR( PJMEDIA_SDP_EINATTR,	    "Invalid SDP attributes"),
    PJ_BUILD_ERR( PJMEDIA_SDP_EINRTPMAP,    "Invalid SDP rtpmap attribute"),
    PJ_BUILD_ERR( PJMEDIA_SDP_ERTPMAPTOOLONG,"SDP rtpmap attribute too long"),
    PJ_BUILD_ERR( PJMEDIA_SDP_EMISSINGRTPMAP,"Missing SDP rtpmap for dynamic payload type"),
    PJ_BUILD_ERR( PJMEDIA_SDP_EINMEDIA,	    "Invalid SDP media line" ),
    PJ_BUILD_ERR( PJMEDIA_SDP_ENOFMT,	    "No SDP payload format in the media line" ),
    PJ_BUILD_ERR( PJMEDIA_SDP_EINPT,	    "Invalid SDP payload type in media line" ),
    PJ_BUILD_ERR( PJMEDIA_SDP_EINFMTP,	    "Invalid SDP fmtp attribute" ),
    PJ_BUILD_ERR( PJMEDIA_SDP_EINRTCP,	    "Invalid SDP rtcp attribyte" ),

    /* SDP negotiator errors. */
    PJ_BUILD_ERR( PJMEDIA_SDPNEG_EINSTATE,	"Invalid SDP negotiator state for operation" ),
    PJ_BUILD_ERR( PJMEDIA_SDPNEG_ENOINITIAL,	"No initial local SDP in SDP negotiator" ),
    PJ_BUILD_ERR( PJMEDIA_SDPNEG_ENOACTIVE,	"No active SDP in SDP negotiator" ),
    PJ_BUILD_ERR( PJMEDIA_SDPNEG_ENONEG,	"No current local/remote offer/answer" ),
    PJ_BUILD_ERR( PJMEDIA_SDPNEG_EMISMEDIA,	"SDP media count mismatch in offer/answer" ),
    PJ_BUILD_ERR( PJMEDIA_SDPNEG_EINVANSMEDIA,	"SDP media type mismatch in offer/answer" ),
    PJ_BUILD_ERR( PJMEDIA_SDPNEG_EINVANSTP,	"SDP media transport type mismatch in offer/answer" ),
    PJ_BUILD_ERR( PJMEDIA_SDPNEG_EANSNOMEDIA,	"No common SDP media payload in answer" ),
    PJ_BUILD_ERR( PJMEDIA_SDPNEG_ENOMEDIA,	"No active media stream after negotiation" ),
    PJ_BUILD_ERR( PJMEDIA_SDPNEG_NOANSCODEC,	"No suitable codec for remote offer"),
    PJ_BUILD_ERR( PJMEDIA_SDPNEG_NOANSTELEVENT,	"No suitable telephone-event for remote offer"),
    PJ_BUILD_ERR( PJMEDIA_SDPNEG_NOANSUNKNOWN,	"No suitable answer for unknown remote offer"),

    /* SDP comparison results */
    PJ_BUILD_ERR( PJMEDIA_SDP_EMEDIANOTEQUAL,   "SDP media descriptor not equal" ),
    PJ_BUILD_ERR( PJMEDIA_SDP_EPORTNOTEQUAL,    "Port in SDP media descriptor not equal" ),
    PJ_BUILD_ERR( PJMEDIA_SDP_ETPORTNOTEQUAL,   "Transport in SDP media descriptor not equal" ),
    PJ_BUILD_ERR( PJMEDIA_SDP_EFORMATNOTEQUAL,  "Format in SDP media descriptor not equal" ),
    PJ_BUILD_ERR( PJMEDIA_SDP_ECONNNOTEQUAL,    "SDP connection line not equal" ),
    PJ_BUILD_ERR( PJMEDIA_SDP_EATTRNOTEQUAL,    "SDP attributes not equal" ),
    PJ_BUILD_ERR( PJMEDIA_SDP_EDIRNOTEQUAL,     "SDP media direction not equal" ),
    PJ_BUILD_ERR( PJMEDIA_SDP_EFMTPNOTEQUAL,    "SDP fmtp attribute not equal" ),
    PJ_BUILD_ERR( PJMEDIA_SDP_ERTPMAPNOTEQUAL,  "SDP rtpmap attribute not equal" ),
    PJ_BUILD_ERR( PJMEDIA_SDP_ESESSNOTEQUAL,    "SDP session descriptor not equal" ),
    PJ_BUILD_ERR( PJMEDIA_SDP_EORIGINNOTEQUAL,  "SDP origin line not equal" ),
    PJ_BUILD_ERR( PJMEDIA_SDP_ENAMENOTEQUAL,    "SDP name/subject line not equal" ),
    PJ_BUILD_ERR( PJMEDIA_SDP_ETIMENOTEQUAL,    "SDP time line not equal" ),

    /* Codec errors. */
    PJ_BUILD_ERR( PJMEDIA_CODEC_EUNSUP,		"Unsupported media codec" ),
    PJ_BUILD_ERR( PJMEDIA_CODEC_EFAILED,	"Codec internal creation error" ),
    PJ_BUILD_ERR( PJMEDIA_CODEC_EFRMTOOSHORT,   "Codec frame is too short" ),
    PJ_BUILD_ERR( PJMEDIA_CODEC_EPCMTOOSHORT,   "PCM frame is too short" ),
    PJ_BUILD_ERR( PJMEDIA_CODEC_EFRMINLEN,      "Invalid codec frame length" ),
    PJ_BUILD_ERR( PJMEDIA_CODEC_EPCMFRMINLEN,   "Invalid PCM frame length" ),
    PJ_BUILD_ERR( PJMEDIA_CODEC_EINMODE,	"Invalid codec mode (no fmtp?)" ),

    /* Media errors. */
    PJ_BUILD_ERR( PJMEDIA_EINVALIDIP,	    "Invalid remote media (IP) address" ),
    PJ_BUILD_ERR( PJMEDIA_EASYMCODEC,	    "Asymetric media codec is not supported" ),
    PJ_BUILD_ERR( PJMEDIA_EINVALIDPT,	    "Invalid media payload type" ),
    PJ_BUILD_ERR( PJMEDIA_EMISSINGRTPMAP,   "Missing rtpmap in media description" ),
    PJ_BUILD_ERR( PJMEDIA_EINVALIMEDIATYPE, "Invalid media type" ),
    PJ_BUILD_ERR( PJMEDIA_EREMOTENODTMF,    "Remote does not support DTMF" ),
    PJ_BUILD_ERR( PJMEDIA_RTP_EINDTMF,	    "Invalid DTMF digit" ),
    PJ_BUILD_ERR( PJMEDIA_RTP_EREMNORFC2833,"Remote does not support RFC 2833" ),

    /* RTP session errors. */
    PJ_BUILD_ERR( PJMEDIA_RTP_EINPKT,	    "Invalid RTP packet" ),
    PJ_BUILD_ERR( PJMEDIA_RTP_EINPACK,	    "Invalid RTP packing (internal error)" ),
    PJ_BUILD_ERR( PJMEDIA_RTP_EINVER,	    "Invalid RTP version" ),
    PJ_BUILD_ERR( PJMEDIA_RTP_EINSSRC,	    "RTP packet SSRC id mismatch" ),
    PJ_BUILD_ERR( PJMEDIA_RTP_EINPT,	    "RTP packet payload type mismatch" ),
    PJ_BUILD_ERR( PJMEDIA_RTP_EINLEN,	    "Invalid RTP packet length" ),
    PJ_BUILD_ERR( PJMEDIA_RTP_ESESSRESTART,    "RTP session restarted" ),
    PJ_BUILD_ERR( PJMEDIA_RTP_ESESSPROBATION,  "RTP session in probation" ),
    PJ_BUILD_ERR( PJMEDIA_RTP_EBADSEQ,	    "Bad sequence number in RTP packet" ),
    PJ_BUILD_ERR( PJMEDIA_RTP_EBADDEST,	    "RTP media port destination is not configured" ),
    PJ_BUILD_ERR( PJMEDIA_RTP_ENOCONFIG,    "RTP is not configured" ),
    
    /* Media port errors: */
    PJ_BUILD_ERR( PJMEDIA_ENOTCOMPATIBLE,   "Media ports are not compatible" ),
    PJ_BUILD_ERR( PJMEDIA_ENCCLOCKRATE,	    "Media ports have incompatible clock rate" ),
    PJ_BUILD_ERR( PJMEDIA_ENCSAMPLESPFRAME, "Media ports have incompatible samples per frame" ),
    PJ_BUILD_ERR( PJMEDIA_ENCTYPE,	    "Media ports have incompatible media type" ),
    PJ_BUILD_ERR( PJMEDIA_ENCBITS,	    "Media ports have incompatible bits per sample" ),
    PJ_BUILD_ERR( PJMEDIA_ENCBYTES,	    "Media ports have incompatible bytes per frame" ),
    PJ_BUILD_ERR( PJMEDIA_ENCCHANNEL,	    "Media ports have incompatible number of channels" ),

    /* Media file errors: */
    PJ_BUILD_ERR( PJMEDIA_ENOTVALIDWAVE,    "Not a valid WAVE file" ),
    PJ_BUILD_ERR( PJMEDIA_EWAVEUNSUPP,	    "Unsupported WAVE file format" ),
    PJ_BUILD_ERR( PJMEDIA_EWAVETOOSHORT,    "WAVE file too short" ),
    PJ_BUILD_ERR( PJMEDIA_EFRMFILETOOBIG,   "Sound frame too large for file buffer"),

    /* Sound device errors: */
    PJ_BUILD_ERR( PJMEDIA_ENOSNDREC,	    "No suitable sound capture device" ),
    PJ_BUILD_ERR( PJMEDIA_ENOSNDPLAY,	    "No suitable sound playback device" ),
    PJ_BUILD_ERR( PJMEDIA_ESNDINDEVID,	    "Invalid sound device ID" ),
    PJ_BUILD_ERR( PJMEDIA_ESNDINSAMPLEFMT,  "Invalid sample format for sound device" ),
};

#endif	/* PJ_HAS_ERROR_STRING */



/*
 * pjmedia_strerror()
 */
PJ_DEF(pj_str_t) pjmedia_strerror( pj_status_t statcode, 
				   char *buf, pj_size_t bufsize )
{
    pj_str_t errstr;

#if defined(PJ_HAS_ERROR_STRING) && (PJ_HAS_ERROR_STRING != 0)

    /* See if the error comes from PortAudio. */
#if PJMEDIA_SOUND_IMPLEMENTATION==PJMEDIA_SOUND_PORTAUDIO_SOUND
    if (statcode >= PJMEDIA_ERRNO_FROM_PORTAUDIO(paNotInitialized) &&
	statcode <  PJMEDIA_ERRNO_FROM_PORTAUDIO(paNotInitialized + 10000))
    {

	int pa_err = statcode - PJMEDIA_ERRNO_FROM_PORTAUDIO(0);
	pj_str_t msg;
	
	msg.ptr = (char*)Pa_GetErrorText(pa_err);
	msg.slen = pj_ansi_strlen(msg.ptr);

	errstr.ptr = buf;
	pj_strncpy_with_null(&errstr, &msg, bufsize);
	return errstr;

    } else 
#endif	/* PJMEDIA_SOUND_IMPLEMENTATION */
    if (statcode >= PJMEDIA_ERRNO_START && 
	       statcode < PJMEDIA_ERRNO_START + PJ_ERRNO_SPACE_SIZE)
    {
	/* Find the error in the table.
	 * Use binary search!
	 */
	int first = 0;
	int n = PJ_ARRAY_SIZE(err_str);

	while (n > 0) {
	    int half = n/2;
	    int mid = first + half;

	    if (err_str[mid].code < statcode) {
		first = mid+1;
		n -= (half+1);
	    } else if (err_str[mid].code > statcode) {
		n = half;
	    } else {
		first = mid;
		break;
	    }
	}


	if (PJ_ARRAY_SIZE(err_str) && err_str[first].code == statcode) {
	    pj_str_t msg;
	    
	    msg.ptr = (char*)err_str[first].msg;
	    msg.slen = pj_ansi_strlen(err_str[first].msg);

	    errstr.ptr = buf;
	    pj_strncpy_with_null(&errstr, &msg, bufsize);
	    return errstr;

	} 
    }

#endif	/* PJ_HAS_ERROR_STRING */

    /* Error not found. */
    errstr.ptr = buf;
    errstr.slen = pj_ansi_snprintf(buf, bufsize, 
				   "Unknown pjmedia error %d",
				   statcode);

    return errstr;
}

