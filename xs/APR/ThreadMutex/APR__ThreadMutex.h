#define apr_thread_mutex_DESTROY apr_thread_mutex_destroy

static MP_INLINE
apr_thread_mutex_t *mpxs_apr_thread_mutex_create(pTHX_ SV *classname,
                                                 apr_pool_t *pool,
                                                 unsigned int flags)
{
    apr_thread_mutex_t *mutex = NULL;
    (void)apr_thread_mutex_create(&mutex, flags, pool);
    return mutex;
}
