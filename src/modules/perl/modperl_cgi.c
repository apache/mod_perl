#include "mod_perl.h"

MP_INLINE int modperl_cgi_header_parse(request_rec *r, char *buffer,
                                       const char **bodytext)
{
    int status;
    int termarg;

    if (!buffer) {
        return DECLINED;
    }

    status = ap_scan_script_header_err_strs(r, NULL, bodytext,
                                            &termarg, buffer, NULL);

    return status;
}
