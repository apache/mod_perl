#ifndef MODPERL_UTIL_H
#define MODPERL_UTIL_H

#ifdef MP_DEBUG
#define MP_INLINE
#else
#define MP_INLINE APR_INLINE
#endif

#ifndef strcaseEQ
#   define strcaseEQ(s1,s2) (!strcasecmp(s1,s2))
#endif
#ifndef strncaseEQ
#   define strncaseEQ(s1,s2,l) (!strncasecmp(s1,s2,l))
#endif

#ifndef SvCLASS
#define SvCLASS(o) HvNAME(SvSTASH(SvRV(o)))
#endif

#define SvObjIV(o) SvIV((SV*)SvRV(o))

MP_INLINE request_rec *modperl_sv2request_rec(pTHX_ SV *sv);

request_rec *modperl_xs_sv2request_rec(pTHX_ SV *sv, char *classname, CV *cv);

MP_INLINE SV *modperl_newSVsv_obj(pTHX_ SV *stashsv, SV *obj);

MP_INLINE SV *modperl_ptr2obj(pTHX_ char *classname, void *ptr);

apr_pool_t *modperl_sv2pool(pTHX_ SV *obj);

char *modperl_apr_strerror(apr_status_t rv);

int modperl_errsv(pTHX_ int status, request_rec *r, server_rec *s);

int modperl_require_module(pTHX_ const char *pv, int logfailure);

char *modperl_server_desc(server_rec *s, apr_pool_t *p);

void modperl_xs_dl_handles_clear(pTHXo);

apr_array_header_t *modperl_xs_dl_handles_get(pTHX_ apr_pool_t *p);

void modperl_xs_dl_handles_close(apr_pool_t *p, apr_array_header_t *handles);

modperl_cleanup_data_t *modperl_cleanup_data_new(apr_pool_t *p, void *data);

#endif /* MODPERL_UTIL_H */
