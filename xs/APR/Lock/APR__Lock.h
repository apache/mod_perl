#define apr_lock_DESTROY(lock) (void)apr_lock_destroy(lock)

static MP_INLINE apr_lock_t *mpxs_apr_lock_create(pTHX_ SV *CLASS,
                                                  apr_pool_t *p,
                                                  apr_locktype_e type,
                                                  apr_lockmech_e mech,
                                                  apr_lockscope_e scope,
                                                  const char *fname)
{
    apr_lock_t *retval=NULL;
    (void)apr_lock_create(&retval, type, mech, scope, fname, p);
    return retval;
}
