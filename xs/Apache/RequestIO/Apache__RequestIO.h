#define mpxs_Apache__RequestRec_TIEHANDLE(stashsv, sv) \
modperl_newSVsv_obj(aTHX_ stashsv, sv)

#define mpxs_Apache__RequestRec_PRINT mpxs_ap_rvputs

#if 0
#define MP_USE_AP_RWRITE
#endif

#ifdef MP_USE_AP_RWRITE

#define mpxs_call_rwrite(r,buf,len) \
ap_rwrite(buf, len, r)

#define mpxs_rwrite_loop(func,obj) \
    while (MARK <= SP) { \
        STRLEN len; \
        char *buf = SvPV(*MARK, len); \
        int wlen = func(obj, buf, len); \
        bytes += wlen; \
        MARK++; \
    }

#endif

static MP_INLINE apr_size_t mpxs_ap_rvputs(pTHX_ I32 items,
                                           SV **MARK, SV **SP)
{
    modperl_config_srv_t *scfg;
    modperl_config_req_t *rcfg;
    apr_size_t bytes = 0;
    request_rec *r;
    dMP_TIMES;

    mpxs_usage_va_1(r, "$r->puts(...)");

    rcfg = modperl_config_req_get(r);
    scfg = modperl_config_srv_get(r->server);

    MP_START_TIMES();

#ifdef MP_USE_AP_RWRITE
    mpxs_rwrite_loop(mpxs_call_rwrite, r);
#else
    mpxs_write_loop(modperl_wbucket_write, &rcfg->wbucket);
#endif

    MP_END_TIMES();
    MP_PRINT_TIMES("r->puts");

    /* XXX: flush if $| */

    return bytes;
}

/* alias */
#define mpxs_Apache__RequestRec_WRITE mpxs_Apache__RequestRec_write

static MP_INLINE
apr_ssize_t mpxs_Apache__RequestRec_write(request_rec *r,
                                          SV *buffer, apr_ssize_t bufsiz,
                                          int offset)
{
    dTHX; /*XXX*/
    apr_ssize_t wlen = bufsiz;
    const char *buf;
    STRLEN svlen;
    MP_dRCFG;

    buf = (const char *)SvPV(buffer, svlen);

    if (bufsiz == -1) {
        wlen = offset ? svlen - offset : svlen;
    }
    else {
        wlen = bufsiz;
    }

    modperl_wbucket_write(&rcfg->wbucket, buf+offset, &wlen);

    return wlen;
}

static MP_INLINE long mpxs_ap_get_client_block(pTHX_ request_rec *r,
                                               SV *buffer, int bufsiz)
{
    long nrd = 0;

    mpxs_sv_grow(buffer, bufsiz);

    nrd = ap_get_client_block(r, SvPVX(buffer), bufsiz);

    if (nrd > 0) {
        mpxs_sv_cur_set(buffer, nrd);
        SvTAINTED_on(buffer);
    }
    else {
        sv_setsv(buffer, &PL_sv_undef); /* XXX */
    }

    return nrd;
}

/* alias */
#define mpxs_Apache__RequestRec_READ mpxs_Apache__RequestRec_read

static long mpxs_Apache__RequestRec_read(request_rec *r,
                                         SV *buffer, int bufsiz,
                                         int offset)
{
    dTHX; /*XXX*/
    long nrd = 0, old_read_length;
    int rc;

    if (!r->read_length) {
        if ((rc = ap_setup_client_block(r, REQUEST_CHUNKED_ERROR)) != OK) {
            ap_log_error(APLOG_MARK, APLOG_ERR|APLOG_NOERRNO, 0,
                         r->server,
                         "mod_perl: ap_setup_client_block failed: %d", rc);
            return 0;
        }
    }

    old_read_length = r->read_length;
    r->read_length = 0;

    if (ap_should_client_block(r)) {
        mpxs_sv_grow(buffer, bufsiz+offset);
        nrd = ap_get_client_block(r, SvPVX(buffer)+offset, bufsiz);
    }

    r->read_length += old_read_length;

    if (nrd > 0) {
        mpxs_sv_cur_set(buffer, nrd+offset);
        SvTAINTED_on(buffer);
    } 
    else {
        sv_setsv(buffer, &PL_sv_undef);
    }

    return nrd;
}

static MP_INLINE
apr_status_t mpxs_Apache__RequestRec_sendfile(request_rec *r,
                                              const char *filename,
                                              apr_off_t offset,
                                              apr_size_t len)
{
    apr_size_t nbytes;
    apr_status_t status;
    apr_file_t *fp;

    status = apr_file_open(&fp, filename, APR_READ|APR_BINARY,
                           APR_OS_DEFAULT, r->pool);

    if (status != APR_SUCCESS) {
        return status;
    }

    if (!len) {
        apr_finfo_t finfo;
        apr_file_info_get(&finfo, APR_FINFO_NORM, fp);
        len = finfo.size;
    }

    status = ap_send_fd(fp, r, offset, len, &nbytes);

    /* apr_file_close(fp); */ /* do not do this */

    return status;
}
