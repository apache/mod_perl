static MP_INLINE apr_bucket_brigade *mpxs_apr_brigade_create(pTHX_ SV *CLASS,
                                                             apr_pool_t *p)
{
    return apr_brigade_create(p);
}
