/*
  eXosip - This is the eXtended osip library.
  Copyright (C) 2002, 2003  Aymeric MOIZARD  - jack@atosc.org
  
  eXosip is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.
  
  eXosip is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.
  
  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/


#ifdef ENABLE_MPATROL
#include <mpatrol.h>
#endif

#include "eXosip2.h"
#include <eXosip2/eXosip.h>

#include <osip2/osip_mt.h>
#include <osip2/osip_condv.h>

/* #include <osip2/global.h> */
#include <osipparser2/osip_md5.h>

/* TAKEN from rcf2617.txt */

#define HASHLEN 16
typedef char HASH[HASHLEN];

#define HASHHEXLEN 32
typedef char HASHHEX[HASHHEXLEN + 1];

#define IN
#define OUT

extern eXosip_t eXosip;

/* Private functions */
static void CvtHex (IN HASH Bin, OUT HASHHEX Hex);
static void DigestCalcHA1 (IN const char *pszAlg, IN const char *pszUserName,
                           IN const char *pszRealm,
                           IN const char *pszPassword,
                           IN const char *pszNonce, IN const char *pszCNonce,
                           OUT HASHHEX SessionKey);
static void DigestCalcResponse (IN HASHHEX HA1, IN const char *pszNonce,
                                IN const char *pszNonceCount,
                                IN const char *pszCNonce,
                                IN const char *pszQop,
                                IN const char *pszMethod,
                                IN const char *pszDigestUri,
                                IN HASHHEX HEntity, OUT HASHHEX Response);

static void
CvtHex (IN HASH Bin, OUT HASHHEX Hex)
{
  unsigned short i;
  unsigned char j;

  for (i = 0; i < HASHLEN; i++)
    {
      j = (Bin[i] >> 4) & 0xf;
      if (j <= 9)
        Hex[i * 2] = (j + '0');
      else
        Hex[i * 2] = (j + 'a' - 10);
      j = Bin[i] & 0xf;
      if (j <= 9)
        Hex[i * 2 + 1] = (j + '0');
      else
        Hex[i * 2 + 1] = (j + 'a' - 10);
    };
  Hex[HASHHEXLEN] = '\0';
}

/* calculate H(A1) as per spec */
static void
DigestCalcHA1 (IN const char *pszAlg,
               IN const char *pszUserName,
               IN const char *pszRealm,
               IN const char *pszPassword,
               IN const char *pszNonce,
               IN const char *pszCNonce, OUT HASHHEX SessionKey)
{
  MD5_CTX Md5Ctx;
  HASH HA1;

  MD5Init (&Md5Ctx);
  MD5Update (&Md5Ctx, (unsigned char *) pszUserName, strlen (pszUserName));
  MD5Update (&Md5Ctx, (unsigned char *) ":", 1);
  MD5Update (&Md5Ctx, (unsigned char *) pszRealm, strlen (pszRealm));
  MD5Update (&Md5Ctx, (unsigned char *) ":", 1);
  MD5Update (&Md5Ctx, (unsigned char *) pszPassword, strlen (pszPassword));
  MD5Final ((unsigned char *) HA1, &Md5Ctx);
  if ((pszAlg != NULL) && osip_strcasecmp (pszAlg, "md5-sess") == 0)
    {
      MD5Init (&Md5Ctx);
      MD5Update (&Md5Ctx, (unsigned char *) HA1, HASHLEN);
      MD5Update (&Md5Ctx, (unsigned char *) ":", 1);
      MD5Update (&Md5Ctx, (unsigned char *) pszNonce, strlen (pszNonce));
      MD5Update (&Md5Ctx, (unsigned char *) ":", 1);
      MD5Update (&Md5Ctx, (unsigned char *) pszCNonce, strlen (pszCNonce));
      MD5Final ((unsigned char *) HA1, &Md5Ctx);
    }
  CvtHex (HA1, SessionKey);
}

/* calculate request-digest/response-digest as per HTTP Digest spec */
static void
DigestCalcResponse (IN HASHHEX HA1,     /* H(A1) */
                    IN const char *pszNonce,    /* nonce from server */
                    IN const char *pszNonceCount,       /* 8 hex digits */
                    IN const char *pszCNonce,   /* client nonce */
                    IN const char *pszQop,      /* qop-value: "", "auth", "auth-int" */
                    IN const char *pszMethod,   /* method from the request */
                    IN const char *pszDigestUri,        /* requested URL */
                    IN HASHHEX HEntity, /* H(entity body) if qop="auth-int" */
                    OUT HASHHEX Response
                    /* request-digest or response-digest */ )
{
  MD5_CTX Md5Ctx;
  HASH HA2;
  HASH RespHash;
  HASHHEX HA2Hex;

  /* calculate H(A2) */
  MD5Init (&Md5Ctx);
  MD5Update (&Md5Ctx, (unsigned char *) pszMethod, strlen (pszMethod));
  MD5Update (&Md5Ctx, (unsigned char *) ":", 1);
  MD5Update (&Md5Ctx, (unsigned char *) pszDigestUri, strlen (pszDigestUri));

  if (pszQop == NULL)
    {
      goto auth_withoutqop;
    }
  else if (0 == strcmp (pszQop, "auth-int"))
    {
      goto auth_withauth_int;
    }
  else if (0 == strcmp (pszQop, "auth"))
    {
      goto auth_withauth;
    }

auth_withoutqop:
  MD5Final ((unsigned char *) HA2, &Md5Ctx);
  CvtHex (HA2, HA2Hex);

  /* calculate response */
  MD5Init (&Md5Ctx);
  MD5Update (&Md5Ctx, (unsigned char *) HA1, HASHHEXLEN);
  MD5Update (&Md5Ctx, (unsigned char *) ":", 1);
  MD5Update (&Md5Ctx, (unsigned char *) pszNonce, strlen (pszNonce));
  MD5Update (&Md5Ctx, (unsigned char *) ":", 1);

  goto end;

auth_withauth_int:

  MD5Update (&Md5Ctx, (unsigned char *) ":", 1);
  MD5Update (&Md5Ctx, (unsigned char *) HEntity, HASHHEXLEN);

auth_withauth:
  MD5Final ((unsigned char *) HA2, &Md5Ctx);
  CvtHex (HA2, HA2Hex);

  /* calculate response */
  MD5Init (&Md5Ctx);
  MD5Update (&Md5Ctx, (unsigned char *) HA1, HASHHEXLEN);
  MD5Update (&Md5Ctx, (unsigned char *) ":", 1);
  MD5Update (&Md5Ctx, (unsigned char *) pszNonce, strlen (pszNonce));
  MD5Update (&Md5Ctx, (unsigned char *) ":", 1);
  MD5Update (&Md5Ctx, (unsigned char *) pszNonceCount, strlen (pszNonceCount));
  MD5Update (&Md5Ctx, (unsigned char *) ":", 1);
  MD5Update (&Md5Ctx, (unsigned char *) pszCNonce, strlen (pszCNonce));
  MD5Update (&Md5Ctx, (unsigned char *) ":", 1);
  MD5Update (&Md5Ctx, (unsigned char *) pszQop, strlen (pszQop));
  MD5Update (&Md5Ctx, (unsigned char *) ":", 1);

end:
  MD5Update (&Md5Ctx, (unsigned char *) HA2Hex, HASHHEXLEN);
  MD5Final ((unsigned char *) RespHash, &Md5Ctx);
  CvtHex (RespHash, Response);
}


int
__eXosip_create_authorization_header (osip_message_t * previous_answer,
                                      const char *rquri, const char *username,
                                      const char *passwd, const char *ha1,
                                      osip_authorization_t ** auth,
                                      const char *method)
{
  osip_authorization_t *aut;
  osip_www_authenticate_t *wa = NULL;

  char *qop=NULL;

  osip_message_get_www_authenticate (previous_answer, 0, &wa);

  /* make some test */
  if (passwd == NULL)
    return -1;
  if (wa == NULL || wa->auth_type == NULL
      || (wa->realm == NULL) || (wa->nonce == NULL))
    {
      OSIP_TRACE (osip_trace
                  (__FILE__, __LINE__, OSIP_ERROR, NULL,
                   "www_authenticate header is not acceptable.\n"));
      return -1;
    }
  if (0 != osip_strcasecmp ("Digest", wa->auth_type))
    {
      OSIP_TRACE (osip_trace
                  (__FILE__, __LINE__, OSIP_ERROR, NULL,
                   "Authentication method not supported. (Digest only).\n"));
      return -1;
    }
  /* "MD5" is invalid, but some servers use it. */
  if (wa->algorithm != NULL && 0 != osip_strcasecmp ("MD5", wa->algorithm)
      && 0 != osip_strcasecmp ("\"MD5\"", wa->algorithm))
    {
      OSIP_TRACE (osip_trace
                  (__FILE__, __LINE__, OSIP_ERROR, NULL,
                   "Authentication method not supported. (Digest only).\n"));
      return -1;
    }
  if (0 != osip_authorization_init (&aut))
    {
      OSIP_TRACE (osip_trace
                  (__FILE__, __LINE__, OSIP_ERROR, NULL,
                   "allocation with authorization_init failed.\n"));
      return -1;
    }

  /* just copy some feilds from response to new request */
  osip_authorization_set_auth_type (aut, osip_strdup ("Digest"));
  osip_authorization_set_realm (aut,
                                osip_strdup (osip_www_authenticate_get_realm
                                             (wa)));
  osip_authorization_set_nonce (aut,
                                osip_strdup (osip_www_authenticate_get_nonce
                                             (wa)));
  if (osip_www_authenticate_get_opaque (wa) != NULL)
    osip_authorization_set_opaque (aut,
                                   osip_strdup
                                   (osip_www_authenticate_get_opaque (wa)));
  /* copy the username field in new request */
  aut->username = osip_malloc (strlen (username) + 3);
  sprintf (aut->username, "\"%s\"", username);

  {
    char *tmp = osip_malloc (strlen (rquri) + 3);

    sprintf (tmp, "\"%s\"", rquri);
    osip_authorization_set_uri (aut, tmp);
  }

  osip_authorization_set_algorithm (aut, osip_strdup ("MD5"));

  qop = osip_www_authenticate_get_qop_options (wa);
  if (qop==NULL || qop[0]=='\0' || strlen(qop)<4)
    qop=NULL;


  {
    char *pszNonce =
      osip_strdup_without_quote (osip_www_authenticate_get_nonce (wa));
    char *pszCNonce = NULL;
    const char *pszUser = username;
    char *pszRealm =
      osip_strdup_without_quote (osip_authorization_get_realm (aut));
    const char *pszPass = NULL;
    char *pszAlg = osip_strdup ("MD5");
    char *szNonceCount = NULL;
    const char *pszMethod = method;     /* previous_answer->cseq->method; */
    char *pszQop = NULL;
    const char *pszURI = rquri;

    HASHHEX HA1;
    HASHHEX HA2 = "";
    HASHHEX Response;
    const char *pha1 = NULL;

    if (qop!=NULL)
      {
	if (qop!=NULL)
	  {
	    /* only accept qop="auth" */
	    pszQop = osip_strdup("auth");
	  }
	szNonceCount = osip_strdup ("00000001");
	pszCNonce = osip_strdup ("0a4f113b");
	
	osip_authorization_set_message_qop (aut, osip_strdup ("auth"));
	osip_authorization_set_nonce_count (aut, osip_strdup (szNonceCount));
	
	{
	  char *tmp = osip_malloc (strlen (pszCNonce) + 3);
	  sprintf (tmp, "\"%s\"", pszCNonce);
	  osip_authorization_set_cnonce (aut, tmp);
	}
      }

    pszPass = passwd;

    if (ha1 && ha1[0])
      {
        /* Depending on algorithm=md5 */
        pha1 = ha1;
      }
    else
      {
        DigestCalcHA1 (pszAlg, pszUser, pszRealm, pszPass, pszNonce,
                       pszCNonce, HA1);
        pha1 = HA1;
      }

    DigestCalcResponse ((char *) pha1, pszNonce, szNonceCount, pszCNonce,
                        pszQop, pszMethod, pszURI, HA2, Response);
    OSIP_TRACE (osip_trace
                (__FILE__, __LINE__, OSIP_INFO4, NULL,
                 "Response in authorization |%s|\n", Response));
    {
      char *resp = osip_malloc (35);

      sprintf (resp, "\"%s\"", Response);
      osip_authorization_set_response (aut, resp);
    }
    osip_free (pszAlg);         /* xkd, 2004-5-13 */
    osip_free (pszNonce);
    osip_free (pszCNonce);
    osip_free (pszRealm);
    osip_free (pszQop);
    osip_free (szNonceCount);
  }

  *auth = aut;
  return 0;
}

int
__eXosip_create_proxy_authorization_header (osip_message_t * previous_answer,
                                            const char *rquri,
                                            const char *username,
                                            const char *passwd,
                                            const char *ha1,
                                            osip_proxy_authorization_t **
                                            auth, const char *method)
{
  osip_proxy_authorization_t *aut;
  osip_proxy_authenticate_t *wa;

  osip_message_get_proxy_authenticate (previous_answer, 0, &wa);

  /* make some test */
  if (passwd == NULL)
    return -1;
  if (wa == NULL || wa->auth_type == NULL
      || (wa->realm == NULL) || (wa->nonce == NULL))
    {
      OSIP_TRACE (osip_trace
                  (__FILE__, __LINE__, OSIP_ERROR, NULL,
                   "www_authenticate header is not acceptable.\n"));
      return -1;
    }
  if (0 != osip_strcasecmp ("Digest", wa->auth_type))
    {
      OSIP_TRACE (osip_trace
                  (__FILE__, __LINE__, OSIP_ERROR, NULL,
                   "Authentication method not supported. (Digest only).\n"));
      return -1;
    }
  /* "MD5" is invalid, but some servers use it. */
  if (wa->algorithm != NULL && 0 != osip_strcasecmp ("MD5", wa->algorithm)
      && 0 != osip_strcasecmp ("\"MD5\"", wa->algorithm))
    {
      OSIP_TRACE (osip_trace
                  (__FILE__, __LINE__, OSIP_ERROR, NULL,
                   "Authentication method not supported. (MD5 Digest only).\n"));
      return -1;
    }
  if (0 != osip_proxy_authorization_init (&aut))
    {
      OSIP_TRACE (osip_trace
                  (__FILE__, __LINE__, OSIP_ERROR, NULL,
                   "allocation with authorization_init failed.\n"));
      return -1;
    }

  /* just copy some feilds from response to new request */
  osip_proxy_authorization_set_auth_type (aut, osip_strdup ("Digest"));
  osip_proxy_authorization_set_realm (aut,
                                      osip_strdup
                                      (osip_proxy_authenticate_get_realm (wa)));
  osip_proxy_authorization_set_nonce (aut,
                                      osip_strdup
                                      (osip_proxy_authenticate_get_nonce (wa)));
  if (osip_proxy_authenticate_get_opaque (wa) != NULL)
    osip_proxy_authorization_set_opaque (aut,
                                         osip_strdup
                                         (osip_proxy_authenticate_get_opaque
                                          (wa)));
  /* copy the username field in new request */
  aut->username = osip_malloc (strlen (username) + 3);
  sprintf (aut->username, "\"%s\"", username);

  {
    char *tmp = osip_malloc (strlen (rquri) + 3);

    sprintf (tmp, "\"%s\"", rquri);
    osip_proxy_authorization_set_uri (aut, tmp);
  }
  osip_proxy_authorization_set_algorithm (aut, osip_strdup ("MD5"));

  {
    char *pszNonce = NULL;
    char *pszCNonce = NULL;
    const char *pszUser = username;
    char *pszRealm =
      osip_strdup_without_quote (osip_proxy_authorization_get_realm (aut));
    const char *pszPass = NULL;
    char *pszAlg = osip_strdup ("MD5");
    char *szNonceCount = NULL;
    char *pszMethod = (char *) method;  /* previous_answer->cseq->method; */
    char *pszQop = NULL;
    const char *pszURI = rquri;

    HASHHEX HA1;
    HASHHEX HA2 = "";
    HASHHEX Response;
    const char *pha1 = NULL;

    pszPass = passwd;

    if (osip_www_authenticate_get_nonce (wa) == NULL)
      return -1;
    pszNonce = osip_strdup_without_quote (osip_www_authenticate_get_nonce (wa));

    /* should upgrade szNonceCount */
    /* should add szNonceCount in aut */
    /* should upgrade pszCNonce */
    /* should add pszCNonce in aut */

    if (osip_proxy_authenticate_get_qop_options (wa) != NULL)
      {
        szNonceCount = osip_strdup ("00000001");
        /* MUST be incremented on each */
        pszQop = osip_strdup (osip_proxy_authenticate_get_qop_options (wa));
        pszCNonce = osip_strdup ("234abcc436e2667097e7fe6eia53e8dd");
      }
    if (ha1 && ha1[0])
      {
        /* Depending on algorithm=md5 */
        pha1 = ha1;
    } else
      {
        DigestCalcHA1 (pszAlg, pszUser, pszRealm, pszPass, pszNonce,
                       pszCNonce, HA1);
        pha1 = HA1;
      }
    DigestCalcResponse ((char *) pha1, pszNonce, szNonceCount, pszCNonce,
                        pszQop, pszMethod, pszURI, HA2, Response);
    OSIP_TRACE (osip_trace
                (__FILE__, __LINE__, OSIP_INFO4, NULL,
                 "Response in proxy_authorization |%s|\n", Response));
    {
      char *resp = osip_malloc (35);

      sprintf (resp, "\"%s\"", Response);
      osip_proxy_authorization_set_response (aut, resp);
    }
    osip_free (pszAlg);         /* xkd, 2004-5-13 */
    osip_free (pszNonce);
    osip_free (pszCNonce);
    osip_free (pszRealm);
    osip_free (pszQop);
    osip_free (szNonceCount);
  }

  *auth = aut;
  return 0;
}
