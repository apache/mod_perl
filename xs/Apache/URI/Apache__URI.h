static MP_INLINE
apr_uri_t *mpxs_Apache__RequestRec_parsed_uri(request_rec *r)
{
    modperl_uri_t *uri = modperl_uri_new(r->pool);

    uri->uri = r->parsed_uri;
    uri->path_info = r->path_info;

    return (apr_uri_t *)uri;
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
