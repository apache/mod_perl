/*
 * XXX: should do something useful if we end up with any bodytext
 */
/* XXX: this should probably named $r->cgi_header_parse
 * and send_cgi_header an alias in Apache::compat
 */
#define mpxs_Apache__RequestRec_send_cgi_header(r, sv) \
{ \
    MP_dRCFG; \
    STRLEN len; \
    const char *bodytext; \
    modperl_cgi_header_parse(r, SvPV(sv,len), &bodytext); \
    rcfg->wbucket->header_parse = 0; \
}

/* XXX: should only be part of Apache::compat */
static MP_INLINE void
mpxs_Apache__RequestRec_send_http_header(request_rec *r, const char *type)
{
    MP_dRCFG;

    if (type) {
        r->content_type = apr_pstrdup(r->pool, type);
    }

    rcfg->wbucket->header_parse = 0; /* turn off PerlOptions +ParseHeaders */
}

static MP_INLINE void
mpxs_Apache__RequestRec_set_last_modified(request_rec *r, apr_time_t mtime)
{
    if (mtime) {
        ap_update_mtime(r, mtime);
    }
    ap_set_last_modified(r);
}
