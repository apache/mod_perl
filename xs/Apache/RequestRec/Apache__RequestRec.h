static MP_INLINE
const char *mpxs_Apache__RequestRec_content_type(pTHX_ request_rec *r,
                                                 SV *type)
{
    const char *retval = r->content_type;

    if (type) {
        MP_dRCFG;
        STRLEN len;
        const char *val = SvPV(type, len);
        ap_set_content_type(r, apr_pmemdup(r->pool, val, len+1));
        MP_CGI_HEADER_PARSER_OFF(rcfg);
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

static MP_INLINE
SV *mpxs_Apache__RequestRec_subprocess_env(pTHX_ request_rec *r,
                                           char *key, SV *val)
{
    /* if called in a void context with no arguments, just
     * populate %ENV and stop.  resetting SetupEnv off makes
     * calling in a void context more than once meaningful.
     */
    if (key == NULL && GIMME_V == G_VOID) {
        MP_dRCFG;
        MpReqSETUP_ENV_Off(rcfg); 
        modperl_env_request_populate(aTHX_ r);
        return &PL_sv_undef;
    }

    return modperl_table_get_set(aTHX_ r->subprocess_env,
                                 key, val, TRUE);
}

static MP_INLINE
apr_finfo_t *mpxs_Apache__RequestRec_finfo(request_rec *r)
{
    return &r->finfo;
}

#define mpxs_Apache__RequestRec_server_root_relative(sv, fname) \
    modperl_server_root_relative(aTHX_ sv, fname)

