/* $Id: errno.h 974 2007-02-19 01:13:53Z bennylp $ */
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
#ifndef __PJSIP_SIMPLE_ERRNO_H__
#define __PJSIP_SIMPLE_ERRNO_H__


#include <pjsip/sip_errno.h>

/**
 * Start of error code relative to PJ_ERRNO_START_USER.
 */
#define PJSIP_SIMPLE_ERRNO_START  (PJ_ERRNO_START_USER + PJ_ERRNO_SPACE_SIZE*2)


/************************************************************
 * EVENT PACKAGE ERRORS
 ***********************************************************/
/**
 * @hideinitializer
 * No event package with the specified name.
 */
#define PJSIP_SIMPLE_ENOPKG	    (PJSIP_SIMPLE_ERRNO_START+1)    /*270001*/
/**
 * @hideinitializer
 * Event package already exists.
 */
#define PJSIP_SIMPLE_EPKGEXISTS	    (PJSIP_SIMPLE_ERRNO_START+2)    /*270002*/


/************************************************************
 * PRESENCE ERROR
 ***********************************************************/
/**
 * @hideinitializer
 * Expecting SUBSCRIBE request
 */
#define PJSIP_SIMPLE_ENOTSUBSCRIBE  (PJSIP_SIMPLE_ERRNO_START+20)   /*270020*/
/**
 * @hideinitializer
 * No presence associated with subscription
 */
#define PJSIP_SIMPLE_ENOPRESENCE    (PJSIP_SIMPLE_ERRNO_START+21)   /*270021*/
/**
 * @hideinitializer
 * No presence info in server subscription
 */
#define PJSIP_SIMPLE_ENOPRESENCEINFO (PJSIP_SIMPLE_ERRNO_START+22)  /*270022*/
/**
 * @hideinitializer
 * Bad Content-Type
 */
#define PJSIP_SIMPLE_EBADCONTENT    (PJSIP_SIMPLE_ERRNO_START+23)   /*270023*/
/**
 * @hideinitializer
 * Bad PIDF Message
 */
#define PJSIP_SIMPLE_EBADPIDF	    (PJSIP_SIMPLE_ERRNO_START+24)   /*270024*/
/**
 * @hideinitializer
 * Bad XPIDF Message
 */
#define PJSIP_SIMPLE_EBADXPIDF	    (PJSIP_SIMPLE_ERRNO_START+25)   /*270025*/


/************************************************************
 * ISCOMPOSING ERRORS
 ***********************************************************/
/**
 * @hideinitializer
 * Bad isComposing XML message.
 */
#define PJSIP_SIMPLE_EBADISCOMPOSE  (PJSIP_SIMPLE_ERRNO_START+40)   /*270040*/


#endif	/* __PJSIP_SIMPLE_ERRNO_H__ */

