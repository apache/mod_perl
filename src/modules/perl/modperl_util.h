#ifndef MODPERL_UTIL_H
#define MODPERL_UTIL_H

#ifdef MP_DEBUG
#define MP_INLINE
#else
#define MP_INLINE apr_inline
#endif

MP_INLINE request_rec *modperl_sv2request_rec(pTHX_ SV *sv);

MP_INLINE SV *modperl_ptr2obj(pTHX_ char *classname, void *ptr);

#define modperl_bless_request_rec(r) \
modperl_ptr2obj("Apache", r)

#endif /* MODPERL_UTIL_H */
