#include "mod_perl.h"
#include "modperl_apache_xs.h"

/*
 * it is not optimal to create an ap_bucket for each element of @_
 * so we use our own mini-buffer to build up a decent size buffer
 * before creating an ap_bucket
 */

/*
 * XXX: should make the modperl_wbucket_t hang off of
 * r->per_request_config to avoid "setaside" copies of small buffers
 * that may happen during ap_pass_brigade()
 */

#ifndef MODPERL_WBUCKET_SIZE
#define MODPERL_WBUCKET_SIZE IOBUFSIZE
#endif

typedef struct {
    int outcnt;
    char outbuf[MODPERL_WBUCKET_SIZE];
    request_rec *r;
} modperl_wbucket_t;

static MP_INLINE void modperl_wbucket_pass(modperl_wbucket_t *b,
                                           void *buf, int len)
{
    ap_bucket_brigade *bb = ap_brigade_create(b->r->pool);
    ap_bucket *bucket = ap_bucket_create_transient(buf, len);
    ap_brigade_append_buckets(bb, bucket);
    ap_pass_brigade(b->r->filters, bb);
}

static MP_INLINE void modperl_wbucket_flush(modperl_wbucket_t *b)
{
    modperl_wbucket_pass(b, b->outbuf, b->outcnt);
    b->outcnt = 0;
}

static MP_INLINE void modperl_wbucket_write(modperl_wbucket_t *b,
                                            void *buf, int len)
{
    if ((len + b->outcnt) > MODPERL_WBUCKET_SIZE) {
        modperl_wbucket_flush(b);
    }

    if (len >= MODPERL_WBUCKET_SIZE) {
        modperl_wbucket_pass(b, buf, len);
    }
    else {
        memcpy(&b->outbuf[b->outcnt], buf, len);
        b->outcnt += len;
    }
}

MP_INLINE apr_size_t modperl_apache_xs_write(pTHX_ SV **mark_ptr, SV **sp_ptr)
{
    modperl_wbucket_t wbucket;
    apr_size_t bytes = 0;

    mark_ptr++;

    wbucket.r = modperl_sv2request_rec(aTHX_ *mark_ptr++);
    wbucket.outcnt = 0;

    if (wbucket.r->connection->aborted) {
        return EOF;
    }

    while (mark_ptr <= sp_ptr) {
        STRLEN len;
        char *buf = SvPV(*mark_ptr, len);
        modperl_wbucket_write(&wbucket, buf, len);
        bytes += len;
        mark_ptr++;
    }

    modperl_wbucket_flush(&wbucket);

    /* XXX: ap_rflush if $| */

    return bytes;
}
