#include "modperl_bucket.h"

static apr_bucket *mpxs_APR__Bucket_new(SV *classname, SV *sv,
                                        int offset, int len)
{
    dTHX; /*XXX*/

    if (!len) {
        (void)SvPV(sv, len);
    }

    return modperl_bucket_sv_create(aTHX_ sv, offset, len);
}

static MP_INLINE const char *mpxs_APR__Bucket_read(apr_bucket *bucket,
                                                   apr_ssize_t wanted)
{
    int rc;
    apr_ssize_t len;
    const char *str;

    rc = apr_bucket_read(bucket, &str, &len, wanted);

    if ((rc != APR_SUCCESS) || !str) {
        if (rc != APR_EOF) {
            /* XXX: croak */
        }
        return NULL;
    }
    else {
        return str;
    }
}

static MP_INLINE int mpxs_APR__Bucket_is_eos(apr_bucket *bucket)
{
    return APR_BUCKET_IS_EOS(bucket);
}

static MP_INLINE void mpxs_APR__Bucket_insert_before(apr_bucket *a,
                                                     apr_bucket *b)
{
    APR_BUCKET_INSERT_BEFORE(a, b);
}

static MP_INLINE void mpxs_APR__Bucket_insert_after(apr_bucket *a,
                                                    apr_bucket *b)
{
    APR_BUCKET_INSERT_AFTER(a, b);
}

static MP_INLINE void mpxs_APR__Bucket_remove(apr_bucket *bucket)
{
    APR_BUCKET_REMOVE(bucket);
}

