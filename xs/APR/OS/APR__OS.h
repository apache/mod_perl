static MP_INLINE apr_os_thread_t mpxs_apr_os_thread_current(pTHX)
{
#if APR_HAS_THREADS
    return apr_os_thread_current();
#else
    return 0;
#endif
}
