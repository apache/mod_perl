/* XXX: this should probably named $r->cgi_header_parse
 * and send_cgi_header an alias in Apache::compat
 */
#define mpxs_Apache__RequestRec_send_cgi_header(r, sv) \
{ \
    MP_dRCFG; \
    STRLEN len; \
    const char *bodytext; \
    MP_CGI_HEADER_PARSER_OFF(rcfg); \
    modperl_cgi_header_parse(r, SvPV(sv,len), &bodytext); \
    if (bodytext) {\
        MP_CHECK_WBUCKET_INIT("$r->send_cgi_header"); \
        len -= (bodytext - SvPVX(sv)); \
        modperl_wbucket_write(aTHX_ rcfg->wbucket, bodytext, &len); \
    } \
}

static MP_INLINE void
mpxs_Apache__RequestRec_set_last_modified(request_rec *r, apr_time_t mtime)
{
    if (mtime) {
        ap_update_mtime(r, mtime);
    }
    ap_set_last_modified(r);
}
