#ifdef WIN32
/* win32 not happy with &PL_sv_no */
#   define SVNO  newSViv(0)
#   define SVYES newSViv(1)
#else
#   define SVNO  &PL_sv_no
#   define SVYES &PL_sv_yes
#endif

#define mpxs_Apache__RequestRec_TIEHANDLE(stashsv, sv) \
modperl_newSVsv_obj(aTHX_ stashsv, sv)

#define mpxs_Apache__RequestRec_PRINT  mpxs_Apache__RequestRec_print
#define mpxs_Apache__RequestRec_PRINTF mpxs_ap_rprintf
#define mpxs_Apache__RequestRec_BINMODE(r) \
    r ? SVYES : SVNO /* noop */
#define mpxs_Apache__RequestRec_CLOSE(r) \
    r ? SVYES : SVNO /* noop */

#define mpxs_Apache__RequestRec_UNTIE(r, refcnt) \
    (r && refcnt) ? SVYES : SVNO /* noop */

#define mpxs_output_flush(r, rcfg) \
    /* if ($|) */ \
    if (IoFLUSH(PL_defoutgv)) { \
        MP_FAILURE_CROAK(modperl_wbucket_flush(rcfg->wbucket)); \
        ap_rflush(r); \
    }

static MP_INLINE apr_size_t mpxs_ap_rvputs(pTHX_ I32 items,
                                           SV **MARK, SV **SP)
{
    modperl_config_req_t *rcfg;
    apr_size_t bytes = 0;
    request_rec *r;
    dMP_TIMES;

    mpxs_usage_va_1(r, "$r->puts(...)");

    rcfg = modperl_config_req_get(r);

    MP_START_TIMES();

    mpxs_write_loop(modperl_wbucket_write, rcfg->wbucket);

    MP_END_TIMES();
    MP_PRINT_TIMES("r->puts");

    /* we do not check $| for this method,
     * only in the functions called by the tied interface
     */

    return bytes;
}

static MP_INLINE
apr_size_t mpxs_Apache__RequestRec_print(pTHX_ I32 items,
                                         SV **MARK, SV **SP)
{
    modperl_config_req_t *rcfg;
    request_rec *r;
    
    /* bytes must be called bytes */
    apr_size_t bytes = 0;
    
    /* this also magically assings to r ;-) */
    mpxs_usage_va_1(r, "$r->print(...)");
    
    rcfg = modperl_config_req_get(r);
    
    mpxs_write_loop(modperl_wbucket_write, rcfg->wbucket);
    
    mpxs_output_flush(r, rcfg);
    
    return bytes;
}  

static MP_INLINE
apr_size_t mpxs_ap_rprintf(pTHX_ I32 items, SV **MARK, SV **SP)
{
    modperl_config_req_t *rcfg;
    request_rec *r;
    apr_size_t bytes = 0;
    SV *sv;

    mpxs_usage_va(2, r, "$r->printf($fmt, ...)");
    
    rcfg = modperl_config_req_get(r);

    /* XXX: we could have an rcfg->sprintf_buffer to reuse this SV
     * across requests
     */
    sv = newSV(0);
    modperl_perl_do_sprintf(aTHX_ sv, items, MARK);
    bytes = SvCUR(sv);

    MP_FAILURE_CROAK(modperl_wbucket_write(aTHX_ rcfg->wbucket,
                                           SvPVX(sv), &bytes));
    
    mpxs_output_flush(r, rcfg);

    SvREFCNT_dec(sv);

    return bytes;
}  

/* alias */
#define mpxs_Apache__RequestRec_WRITE(r, buffer, bufsiz, offset) \
    mpxs_Apache__RequestRec_write(aTHX_ r, buffer, bufsiz, offset)

static MP_INLINE
apr_size_t mpxs_Apache__RequestRec_write(pTHX_ request_rec *r,
                                         SV *buffer, apr_size_t bufsiz,
                                         int offset)
{
    apr_size_t wlen = bufsiz;
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

    MP_FAILURE_CROAK(modperl_wbucket_write(aTHX_ rcfg->wbucket,
                                           buf+offset, &wlen));
    
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
        sv_setpvn(buffer, "", 0);
    }

    return nrd;
}

static MP_INLINE
apr_status_t mpxs_setup_client_block(request_rec *r)
{
    if (!r->read_length) {
        apr_status_t rc;

        /* only do this once per-request */
        if ((rc = ap_setup_client_block(r, REQUEST_CHUNKED_ERROR)) != OK) {
            ap_log_error(APLOG_MARK, APLOG_ERR, 0, r->server,
                         "mod_perl: ap_setup_client_block failed: %d", rc);
            return rc;
        }
    }

    return APR_SUCCESS;
}

#define mpxs_should_client_block(r) \
    (r->read_length || ap_should_client_block(r))

/* alias */
#define mpxs_Apache__RequestRec_READ(r, buffer, bufsiz, offset) \
    mpxs_Apache__RequestRec_read(aTHX_ r, buffer, bufsiz, offset)

static long mpxs_Apache__RequestRec_read(pTHX_ request_rec *r,
                                         SV *buffer, int bufsiz,
                                         int offset)
{
    long total = 0;
    int rc;

    if ((rc = mpxs_setup_client_block(r)) != APR_SUCCESS) {
        return 0;
    }

    if (mpxs_should_client_block(r)) {
        long nrd;
        /* ap_should_client_block() will return 0 if r->read_length */
        mpxs_sv_grow(buffer, bufsiz+offset);
        while (bufsiz) {
            nrd = ap_get_client_block(r, SvPVX(buffer)+offset+total, bufsiz);
            if (nrd > 0) {
                total  += nrd;
                bufsiz -= nrd;
            }
            else if (nrd == 0) {
                break;
            }
            else {
                /*
                 * XXX: as stated in ap_get_client_block, the real
                 * error gets lots, so we only know that there was one
                 */
                ap_log_error(APLOG_MARK, APLOG_ERR, 0, r->server,
                         "mod_perl: $r->read failed to read");
                break;
            }
        }
    }

    if (total > 0) {
        mpxs_sv_cur_set(buffer, offset+total);
        SvTAINTED_on(buffer);
    } 
    else {
        sv_setpvn(buffer, "", 0);
    }

    return total;
}

static MP_INLINE
SV *mpxs_Apache__RequestRec_GETC(pTHX_ request_rec *r)
{
    char c[1] = "\0";

    if (mpxs_setup_client_block(r) == APR_SUCCESS) {
        if (mpxs_should_client_block(r)) {
            if (ap_get_client_block(r, c, 1) == 1) {
                return newSVpvn((char *)&c, 1);
            }
        }
    }

    return &PL_sv_undef;
}

static MP_INLINE
int mpxs_Apache__RequestRec_OPEN(pTHX_ SV *self,  SV *arg1, SV *arg2)
{
    char *name;
    STRLEN len;
    SV *arg;
    dHANDLE("STDOUT");
    
    modperl_io_handle_untie(aTHX_ handle); /* untie *STDOUT */
 
    if (arg2 && self) {
        arg = newSVsv(arg1);
        sv_catsv(arg, arg2);
    }
    else {
        arg = arg1;
    }

    name = SvPV(arg, len);
    return do_open(handle, name, len, FALSE, O_RDONLY, 0, Nullfp);
}

static MP_INLINE
int mpxs_Apache__RequestRec_FILENO(pTHX_ request_rec *r)
{
    dHANDLE("STDOUT");
    return PerlIO_fileno(IoOFP(TIEHANDLE_SV(handle)));
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
