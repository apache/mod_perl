static MP_INLINE
char *mpxs_apr_uri_unparse(pTHX_
                           apr_uri_t *uptr,
                           unsigned flags)
{

    /* XXX: check that my patch was actually applied in apr v9.3 */
#if APR_MINOR_VERSION == 9 && APR_PATCH_VERSION < 3
    /* apr < 0.9.3 segfaults if hostname is set, but scheme is not */
    if (uptr->hostname && !uptr->scheme) {
        uptr->scheme = "http";
    }
#endif
    
    return apr_uri_unparse(((modperl_uri_t *)uptr)->pool,
                           uptr, flags);
}

static MP_INLINE
apr_uri_t *mpxs_apr_uri_parse(pTHX_
                              SV *classname,
                              apr_pool_t *p,
                              const char *uri_string)
{
    modperl_uri_t *uri = modperl_uri_new(p);

    (void)apr_uri_parse(p, uri_string, &uri->uri);

    return (apr_uri_t *)uri;
}

static MP_INLINE
char *mpxs_APR__URI_port(pTHX_ apr_uri_t *uri, SV *portsv)
{
    char *port_str = uri->port_str;

    if (portsv) {
        STRLEN len;
        char *port = SvPV(portsv, len);
        uri->port_str = apr_pstrndup(((modperl_uri_t *)uri)->pool,
                                     port, len);
        uri->port = (int)SvIV(portsv);
    }

    return port_str;
}
