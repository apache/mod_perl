static MP_INLINE
apr_finfo_t *mpxs_Apache__RequestRec_finfo(request_rec *r)
{
    return &r->finfo;
}
