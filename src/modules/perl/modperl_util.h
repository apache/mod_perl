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

MP_INLINE request_rec *modperl_sv2request_rec(pTHX_ SV *sv);

MP_INLINE SV *modperl_ptr2obj(pTHX_ char *classname, void *ptr);

#define modperl_bless_request_rec(r) \
modperl_ptr2obj("Apache", r)

char *modperl_apr_strerror(apr_status_t rv);

int modperl_errsv(pTHX_ int status, request_rec *r, server_rec *s);

int modperl_require_module(pTHX_ const char *pv);

char *modperl_server_desc(server_rec *s, apr_pool_t *p);

#endif /* MODPERL_UTIL_H */
