static MP_INLINE
const char *mpxs_Apache__RequestRec_content_type(pTHX_ request_rec *r,
                                                 SV *type)
{
    const char *retval = r->content_type;

    if (type) {
        STRLEN len;
        const char *val = SvPV(type, len);
        ap_set_content_type(r, apr_pmemdup(r->pool, val, len+1));
    }

    return retval;
}

static MP_INLINE
int mpxs_Apache__RequestRec_proxyreq(pTHX_ request_rec *r, SV *val)
{
    int retval = r->proxyreq;

    if (!val && !r->proxyreq &&
        r->parsed_uri.scheme &&
	!(r->parsed_uri.hostname && 
	  strEQ(r->parsed_uri.scheme, ap_http_method(r)) &&
	  ap_matches_request_vhost(r, r->parsed_uri.hostname,
                                   r->parsed_uri.port_str ? 
                                   r->parsed_uri.port : 
                                   ap_default_port(r))))
    {
        retval = r->proxyreq = 1;
        r->uri = r->unparsed_uri;
        /* else mod_proxy will segfault */
        r->filename = apr_pstrcat(r->pool, "modperl-proxy:", r->uri, NULL);
    }

    if (val) {
        r->proxyreq = SvIV(val);
    }

    return retval;
}
