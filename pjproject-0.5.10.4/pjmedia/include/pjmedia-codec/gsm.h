/* $Id: gsm.h 974 2007-02-19 01:13:53Z bennylp $ */
/* 
 * Copyright (C)2003-2007 Benny Prijono <benny@prijono.org>
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
#ifndef __PJMEDIA_CODEC_GSM_H__
#define __PJMEDIA_CODEC_GSM_H__

/**
 * @file pjmedia-codec/gsm.h
 * @brief GSM 06.10 codec.
 */

#include <pjmedia-codec/types.h>

/**
 * @defgroup PJMED_GSM GSM 06.10 Codec
 * @ingroup PJMEDIA_CODEC
 * @brief Implementation of GSM FR based on GSM 06.10 library
 * @{
 * This section describes functions to register and register GSM codec
 * factory to the codec manager. After the codec factory has been registered,
 * application can use @ref PJMEDIA_CODEC API to manipulate the codec.
 */

PJ_BEGIN_DECL


/**
 * Initialize and register GSM codec factory to pjmedia endpoint.
 *
 * @param endpt	    The pjmedia endpoint.
 *
 * @return	    PJ_SUCCESS on success.
 */
PJ_DECL(pj_status_t) pjmedia_codec_gsm_init( pjmedia_endpt *endpt );



/**
 * Unregister GSM codec factory from pjmedia endpoint and deinitialize
 * the GSM codec library.
 *
 * @return	    PJ_SUCCESS on success.
 */
PJ_DECL(pj_status_t) pjmedia_codec_gsm_deinit(void);


PJ_END_DECL


/**
 * @}
 */

#endif	/* __PJMEDIA_CODEC_GSM_H__ */

