/* subclass uri_components */
typedef struct {
    uri_components uri;
    apr_pool_t *pool;
    char *path_info;
} modperl_uri_t;

static MP_INLINE
modperl_uri_t *mpxs_uri_new(apr_pool_t *p)
{
    modperl_uri_t *uri = (modperl_uri_t *)apr_pcalloc(p, sizeof(*uri));
    uri->pool = p;
    return uri;
}

static MP_INLINE
uri_components *mpxs_Apache__RequestRec_parsed_uri(request_rec *r)
{
    modperl_uri_t *uri = mpxs_uri_new(r->pool);

    uri->uri = r->parsed_uri;
    uri->path_info = r->path_info;

    return (uri_components *)uri;
}

static MP_INLINE
char *mpxs_ap_unparse_uri_components(pTHX_
                                     uri_components *uptr,
                                     unsigned flags)
{
    return ap_unparse_uri_components(((modperl_uri_t *)uptr)->pool,
                                     uptr, flags);
}

static MP_INLINE
uri_components *mpxs_ap_parse_uri_components(pTHX_
                                             SV *classname,
                                             SV *obj,
                                             const char *uri_string)
{
    request_rec *r = NULL;
    apr_pool_t *p = modperl_sv2pool(aTHX_ obj);
    modperl_uri_t *uri = mpxs_uri_new(p);

    if (!p) {
        return NULL;
    }

    if (!uri_string) {
        r = mp_xs_sv2_r(obj);
        uri_string = ap_construct_url(r->pool, r->uri, r);
    }

    (void)ap_parse_uri_components(p, uri_string, &uri->uri);

    if (r) {
        uri->uri.query = r->args;
    }

    return (uri_components *)uri;
}

static MP_INLINE int mpxs_ap_unescape_url(pTHX_ SV *url)
{
    int status;
    STRLEN n_a;

    (void)SvPV_force(url, n_a);

    if ((status = ap_unescape_url(SvPVX(url))) == OK) {
        SvCUR_set(url, strlen(SvPVX(url)));
    }

    return status;
}

static MP_INLINE
char *mpxs_Apache__URI_port(uri_components *uri, SV *portsv)
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
