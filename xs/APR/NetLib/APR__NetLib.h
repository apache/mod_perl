static MP_INLINE
apr_ipsubnet_t *mpxs_apr_ipsubnet_create(pTHX_ SV *classname, apr_pool_t *p,
                                         const char *ipstr,
                                         const char *mask_or_numbits)
{
    apr_status_t status;
    apr_ipsubnet_t *ipsub = NULL;
    status = apr_ipsubnet_create(&ipsub, ipstr, mask_or_numbits, p);
    if (status != APR_SUCCESS) {
        return NULL;
    }
    return ipsub;
}
