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
