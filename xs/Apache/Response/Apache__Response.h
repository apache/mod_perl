/* 
 * pretty sure we need to copy SvPVX, otherwise it will be modified inline
 * XXX: that might be a desired feature
 */
/* XXX: this should probably named $r->cgi_header_parse
 * and send_cgi_header an alias in Apache::compat
 */
#define mpxs_Apache__RequestRec_send_cgi_header(r, sv) \
{ \
    STRLEN len; \
    char *buff = SvPV(sv, len); \
    char *copy = apr_palloc(r->pool, len+1); \
    const char *bodytext; \
    apr_cpystrn(copy, buff, len+1); \
    modperl_cgi_header_parse(r, copy, &bodytext); \
}
