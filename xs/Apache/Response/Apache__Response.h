/*
 * XXX: should do something useful if we end up with any bodytext
 */
/* XXX: this should probably named $r->cgi_header_parse
 * and send_cgi_header an alias in Apache::compat
 */
#define mpxs_Apache__RequestRec_send_cgi_header(r, sv) \
{ \
    STRLEN len; \
    const char *bodytext; \
    modperl_cgi_header_parse(r, SvPV(sv,len), &bodytext); \
}
