static MP_INLINE
char *mpxs_apr_uri_unparse_components(pTHX_
                                      apr_uri_components *uptr,
                                      unsigned flags)
{
    return apr_uri_unparse_components(((modperl_uri_t *)uptr)->pool,
                                      uptr, flags);
}

static MP_INLINE
apr_uri_components *mpxs_apr_uri_parse_components(pTHX_
                                                  SV *classname,
                                                  SV *obj,
                                                  const char *uri_string)
{
    request_rec *r = NULL;
    apr_pool_t *p = modperl_sv2pool(aTHX_ obj);
    modperl_uri_t *uri = modperl_uri_new(p);

    if (!p) {
        return NULL;
    }
#if 0
    if (!uri_string) {
        r = mp_xs_sv2_r(obj);
        uri_string = ap_construct_url(r->pool, r->uri, r); /*XXX*/
    }
#endif
    (void)apr_uri_parse_components(p, uri_string, &uri->uri);

    if (r) {
        uri->uri.query = r->args;
    }

    return (apr_uri_components *)uri;
}

static MP_INLINE
char *mpxs_APR__URI_port(apr_uri_components *uri, SV *portsv)
{
    dTHX; /*XXX*/
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
