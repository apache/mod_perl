#define apr_pool_DESTROY(p) apr_pool_destroy(p)

static MP_INLINE apr_pool_t *mpxs_apr_pool_create(pTHX_ SV *obj)
{
    apr_pool_t *parent = (apr_pool_t *)mpxs_sv_object_deref(obj);
    apr_pool_t *retval = NULL;
    (void)apr_pool_create(&retval, parent);
    return retval;
}
