static MP_INLINE
apr_bucket_brigade *mpxs_apr_brigade_create(pTHX_ SV *CLASS,
                                            apr_pool_t *p,
                                            apr_bucket_alloc_t *ba)
{
    return apr_brigade_create(p, ba);
}

#define get_brigade(brigade, fetch) \
(fetch(brigade) == APR_BRIGADE_SENTINEL(brigade) ? \
 NULL : fetch(brigade))

static MP_INLINE
apr_bucket *mpxs_APR__Brigade_first(apr_bucket_brigade *brigade)
{
    return get_brigade(brigade, APR_BRIGADE_FIRST);
}

static MP_INLINE
apr_bucket *mpxs_APR__Brigade_last(apr_bucket_brigade *brigade)
{
    return get_brigade(brigade, APR_BRIGADE_LAST);
}

#define get_bucket(brigade, bucket, fetch) \
(fetch(bucket) == APR_BRIGADE_SENTINEL(brigade) ? \
 NULL : fetch(bucket))

static MP_INLINE
apr_bucket *mpxs_APR__Brigade_next(apr_bucket_brigade *brigade,
                                    apr_bucket *bucket)
{
    return get_bucket(brigade, bucket, APR_BUCKET_NEXT);
}

static MP_INLINE
apr_bucket *mpxs_APR__Brigade_prev(apr_bucket_brigade *brigade,
                                   apr_bucket *bucket)
{
    return get_bucket(brigade, bucket, APR_BUCKET_PREV);
}

static MP_INLINE
void mpxs_APR__Brigade_insert_tail(apr_bucket_brigade *brigade,
                                   apr_bucket *bucket)
{
    APR_BRIGADE_INSERT_TAIL(brigade, bucket);
}

static MP_INLINE
void mpxs_APR__Brigade_insert_head(apr_bucket_brigade *brigade,
                                   apr_bucket *bucket)
{
    APR_BRIGADE_INSERT_HEAD(brigade, bucket);
}

static MP_INLINE
void mpxs_APR__Brigade_concat(apr_bucket_brigade *a,
                              apr_bucket_brigade *b)
{
    APR_BRIGADE_CONCAT(a, b);
}

static MP_INLINE
int mpxs_APR__Brigade_empty(apr_bucket_brigade *brigade)
{
    return APR_BRIGADE_EMPTY(brigade);
}

static MP_INLINE
SV *mpxs_APR__Brigade_length(pTHX_ apr_bucket_brigade *bb,
                             int read_all)
{
    apr_off_t length;

    apr_status_t rv = apr_brigade_length(bb, read_all, &length);

    /* XXX - we're deviating from the API here a bit in order to
     * make it more perlish - returning the length instead of
     * the return code.  maybe that's not such a good idea, though...
     */
    if (rv == APR_SUCCESS) {
        return newSViv((int)length);
    }

    return &PL_sv_undef;
}

static MP_INLINE
apr_status_t mpxs_apr_brigade_flatten(pTHX_ apr_bucket_brigade *bb,
                                      SV *sv_buf, SV *sv_len)
{
    apr_status_t status;
    apr_size_t len = mp_xs_sv2_apr_size_t(sv_len);

    mpxs_sv_grow(sv_buf, len);
    status = apr_brigade_flatten(bb, SvPVX(sv_buf), &len);
    mpxs_sv_cur_set(sv_buf, len);

    if (!SvREADONLY(sv_len)) {
        sv_setiv(sv_len, len);
    }

    return status;
}
