#include "mod_perl.h"
#include "modperl_apache_xs.h"

#define mpxs_write_loop(func,obj) \
    while (MARK <= SP) { \
        apr_ssize_t wlen; \
        char *buf = SvPV(*MARK, wlen); \
        apr_status_t rv = func(obj, buf, &wlen); \
        if (rv != APR_SUCCESS) { \
            croak(modperl_apr_strerror(rv)); \
        } \
        bytes += wlen; \
        MARK++; \
    }

#if 0
#define MP_USE_AP_RWRITE
#endif

#ifdef MP_USE_AP_RWRITE

#define mpxs_ap_rwrite(r,buf,len) \
ap_rwrite(buf, len, r)

#define mpxs_rwrite_loop(func,obj) \
    while (MARK <= SP) { \
        STRLEN len; \
        char *buf = SvPV(*MARK, len); \
        int wlen = func(obj, buf, len); \
        bytes += wlen; \
        MARK++; \
    }

#endif

/*
 * it is not optimal to create an ap_bucket for each element of @_
 * so we use our own mini-buffer to build up a decent size buffer
 * before creating an ap_bucket
 * this buffer is flushed when full or after PerlResponseHandlers are run
 */

/* XXX: maybe we should just let xsubpp do its job */
#define modperl_sv2r modperl_sv2request_rec

#define mpxs_sv2obj(obj) \
(obj = modperl_sv2##obj(aTHX_ *MARK++))

#define mpxs_usage(i, obj, msg) \
if ((items < i) || !(mpxs_sv2obj(obj))) \
croak("usage: %s", msg)

#define mpxs_usage_1(obj, msg) mpxs_usage(1, obj, msg)

#define mpxs_usage_2(obj, arg, msg) \
mpxs_usage(2, obj, msg); \
arg = *MARK++

MP_INLINE apr_size_t modperl_apache_xs_write(pTHX_ I32 items,
                                             SV **MARK, SV **SP)
{
    modperl_srv_config_t *scfg;
    modperl_request_config_t *rcfg;
    apr_size_t bytes = 0;
    request_rec *r;
    dMP_TIMES;

    mpxs_usage_1(r, "$r->write(...)");

    rcfg = modperl_request_config_get(r);
    scfg = modperl_srv_config_get(r->server);

    MP_START_TIMES();

#ifdef MP_USE_AP_RWRITE
    mpxs_rwrite_loop(mpxs_ap_rwrite, r);
#else
    mpxs_write_loop(modperl_wbucket_write, &rcfg->wbucket);
#endif

    MP_END_TIMES();
    MP_PRINT_TIMES("r->write");

    /* XXX: flush if $| */

    return bytes;
}

MP_INLINE apr_size_t modperl_filter_xs_write(pTHX_ I32 items,
                                             SV **MARK, SV **SP)
{
    modperl_filter_t *filter;
    apr_size_t bytes = 0;

    mpxs_usage_1(filter, "$filter->write(...)");

    if (filter->mode == MP_OUTPUT_FILTER_MODE) {
        mpxs_write_loop(modperl_output_filter_write, filter);
        modperl_output_filter_flush(filter);
    }
    else {
        croak("input filters not yet supported");
    }

    /* XXX: ap_rflush if $| */

    return bytes;
}

MP_INLINE apr_size_t modperl_filter_xs_read(pTHX_ I32 items,
                                            SV **MARK, SV **SP)
{
    modperl_filter_t *filter;
    apr_size_t wanted, len=0;
    SV *buffer;

    mpxs_usage_2(filter, buffer, "$filter->read(buf, [len])");

    if (items > 2) {
        wanted = SvIV(*MARK);
    }
    else {
        wanted = IOBUFSIZE;
    }

    if (filter->mode == MP_OUTPUT_FILTER_MODE) {
        len = modperl_output_filter_read(aTHX_ filter, buffer, wanted);
    }
    else {
        croak("input filters not yet supported");
    }

    return len;
}
