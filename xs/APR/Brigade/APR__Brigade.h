static MP_INLINE
apr_bucket_brigade *mpxs_apr_brigade_create(pTHX_ SV *CLASS,
                                            apr_pool_t *p)
{
    return apr_brigade_create(p);
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

