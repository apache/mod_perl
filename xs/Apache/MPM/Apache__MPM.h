static MP_INLINE
int mpxs_Apache__MPM_mpm_query(int query)
{
    int mpm_query_info;

    apr_status_t retval = ap_mpm_query(query, &mpm_query_info);

    if (retval == APR_SUCCESS) {
        return mpm_query_info;
    }

    /* XXX hmm... what to do here.  die?
     * APR_ENOTIMPL should be sufficiently large
     * that comparison tests fail... I think...
     */
    return (int) retval;
}
