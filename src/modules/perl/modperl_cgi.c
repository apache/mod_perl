#include "mod_perl.h"

MP_INLINE int modperl_cgi_header_parse(request_rec *r, char *buffer,
                                       const char **bodytext)
{
    int status;
    int termarg;
    const char *location;

    if (!buffer) {
        return DECLINED;
    }

    status = ap_scan_script_header_err_strs(r, NULL, bodytext,
                                            &termarg, buffer, NULL);

    /* code below from mod_cgi.c */
    location = apr_table_get(r->headers_out, "Location");

    if (location && (location[0] == '/') && (r->status == 200)) {
        r->method = apr_pstrdup(r->pool, "GET");
        r->method_number = M_GET;

        /* We already read the message body (if any), so don't allow
         * the redirected request to think it has one.  We can ignore 
         * Transfer-Encoding, since we used REQUEST_CHUNKED_ERROR.
         */
        apr_table_unset(r->headers_in, "Content-Length");

        ap_internal_redirect_handler(location, r);

        return OK;
    }
    else if (location && (r->status == 200)) {
        MP_dRCFG;

        /* Note that if a script wants to produce its own Redirect
         * body, it now has to explicitly *say* "Status: 302"
         */

        /* XXX: this is a hack.
         * filter return value doesn't seem to impact anything.
         */
        rcfg->status = HTTP_MOVED_TEMPORARILY;

        return HTTP_MOVED_TEMPORARILY;
    }

    return status;
}
