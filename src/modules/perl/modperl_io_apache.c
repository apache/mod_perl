#include "mod_perl.h"

#ifdef MP_IO_TIE_PERLIO

/***************************
 * The PerlIO Apache layer *
 ***************************/

/* PerlIO ":Apache" layer is used to use the Apache callbacks to read
 * from STDIN and write to STDOUT. The PerlIO API is documented in
 * perliol.pod */

typedef struct {
    struct _PerlIO base;
    request_rec *r;
} PerlIOApache;

/* _open just allocates the layer, _pushed does the real job of
 * filling the data in */
static PerlIO *
PerlIOApache_open(pTHX_ PerlIO_funcs *self, PerlIO_list_t *layers, IV n,
		  const char *mode, int fd, int imode, int perm,
		  PerlIO *f, int narg, SV **args)
{
    if (!f) {
        f = PerlIO_allocate(aTHX);
    }
    if ( (f = PerlIO_push(aTHX_ f, self, mode, args[0])) ) {
        PerlIOBase(f)->flags |= PERLIO_F_OPEN;
    }

    MP_TRACE_o(MP_FUNC, "mode %s", mode);

    return f;
}

/* this callback is used by pushed() and binmode() to add the layer */
static IV
PerlIOApache_pushed(pTHX_ PerlIO *f, const char *mode, SV *arg,
		    PerlIO_funcs *tab)
{
    IV code;
    PerlIOApache *st = PerlIOSelf(f, PerlIOApache);

    if (arg) {
        st->r = modperl_sv2request_rec(aTHX_ arg);
    }
    else {
        Perl_croak(aTHX_ "$r wasn't passed");
        /* XXX: try to get Apache->request? */
    }
    
    /* this method also sets the right flags according to the
     * 'mode' */
    code = PerlIOBase_pushed(aTHX_ f, mode, Nullsv, tab);
    
    MP_TRACE_o(MP_FUNC, "done");
    
    return code;
}

static IV
PerlIOApache_fileno(pTHX_ PerlIO *f)
{
    /* XXX: we could return STDIN => 0, STDOUT => 2, but that wouldn't
     * be correct, as the IO goes through the socket, may be we should
     * return the filedescriptor of the socket? 
     *
     * -1 in this case indicates that the layer cannot provide fileno
     */
    MP_TRACE_o(MP_FUNC, "did nothing");
    return -1;
}


/* XXX: FIXME */
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

static SSize_t
PerlIOApache_read(pTHX_ PerlIO *f, void *vbuf, Size_t count)
{
    PerlIOApache *st = PerlIOSelf(f, PerlIOApache);
    request_rec *r = st->r;
    long total = 0;
    int rc;

    if (!(PerlIOBase(f)->flags & PERLIO_F_CANREAD) ||
        PerlIOBase(f)->flags & (PERLIO_F_EOF|PERLIO_F_ERROR)) {
	return 0;
    }
    
    if ((rc = mpxs_setup_client_block(r)) != APR_SUCCESS) {
        return 0;
    }

    if (mpxs_should_client_block(r)) {
        total = ap_get_client_block(r, vbuf, count);

        MP_TRACE_o(MP_FUNC, "wanted %db, read %db [%s]",
                   count, total, (char *)vbuf);

        if (total < 0) {
            /*
             * XXX: as stated in ap_get_client_block, the real
             * error gets lots, so we only know that there was one
             */
            ap_log_error(APLOG_MARK, APLOG_ERR, 0, r->server,
                         "mod_perl: $r->read failed to read");
        }
    }

    return total;
}

static SSize_t
PerlIOApache_write(pTHX_ PerlIO *f, const void *vbuf, Size_t count)
{
    PerlIOApache *st = PerlIOSelf(f, PerlIOApache);
    modperl_config_req_t *rcfg = modperl_config_req_get(st->r);
    apr_size_t bytes = 0;
    apr_status_t rv;

    if (!(PerlIOBase(f)->flags & PERLIO_F_CANWRITE)) {
	return 0;
    }
    
    MP_CHECK_WBUCKET_INIT("print");

    MP_TRACE_o(MP_FUNC, "%d bytes [%s]", count, (char *)vbuf);
        
    rv = modperl_wbucket_write(aTHX_ rcfg->wbucket, vbuf, &count);
    if (rv != APR_SUCCESS) {
        Perl_croak(aTHX_ modperl_apr_strerror(rv)); 
    }
    bytes += count;
    
    return (SSize_t) bytes;
}

static IV
PerlIOApache_flush(pTHX_ PerlIO *f)
{
    PerlIOApache *st = PerlIOSelf(f, PerlIOApache);
    modperl_config_req_t *rcfg = modperl_config_req_get(st->r);

    /* no flush on readonly io handle */
    if (! (PerlIOBase(f)->flags & PERLIO_F_CANWRITE) ) {
        return -1;
    }

    MP_CHECK_WBUCKET_INIT("flush");

    MP_TRACE_o(MP_FUNC, "%d bytes [%s]", rcfg->wbucket->outcnt,
               apr_pstrmemdup(rcfg->wbucket->pool, rcfg->wbucket->outbuf,
                              rcfg->wbucket->outcnt));

    MP_FAILURE_CROAK(modperl_wbucket_flush(rcfg->wbucket, FALSE));

    return 0;
}

/* 5.8.0 doesn't export PerlIOBase_noop_fail, so we duplicate it here */
static IV PerlIOApache_noop_fail(pTHX_ PerlIO *f)
{
    return -1;
}

static IV
PerlIOApache_close(pTHX_ PerlIO *f)
{
    /* XXX: just temp for tracing */
    MP_TRACE_o(MP_FUNC, "done");
    return PerlIOBase_close(aTHX_ f);
}

static IV
PerlIOApache_popped(pTHX_ PerlIO *f)
{
    /* XXX: just temp for tracing */
    MP_TRACE_o(MP_FUNC, "done");
    return PerlIOBase_popped(aTHX_ f);
}


static PerlIO_funcs PerlIO_Apache = {
    sizeof(PerlIO_funcs),
    "Apache",
    sizeof(PerlIOApache),
    PERLIO_K_MULTIARG,
    PerlIOApache_pushed,
    PerlIOApache_popped,
    PerlIOApache_open,
    PerlIOBase_binmode,
    NULL,                       /* no getarg needed */
    PerlIOApache_fileno,
    PerlIOBase_dup,
    PerlIOApache_read,
    PerlIOBase_unread,
    PerlIOApache_write,
    NULL,                       /* can't seek on STD{IN|OUT}, fail on call*/
    NULL,                       /* can't tell on STD{IN|OUT}, fail on call*/
    PerlIOApache_close,
    PerlIOApache_flush,        
    PerlIOApache_noop_fail,     /* fill */
    PerlIOBase_eof,
    PerlIOBase_error,
    PerlIOBase_clearerr,
    PerlIOBase_setlinebuf,
    NULL,                       /* get_base */
    NULL,                       /* get_bufsiz */
    NULL,                       /* get_ptr */
    NULL,                       /* get_cnt */
    NULL,                       /* set_ptrcnt */
};

/* ***** End of PerlIOApache tab ***** */

MP_INLINE void modperl_io_apache_init(pTHX)
{
    PerlIO_define_layer(aTHX_ &PerlIO_Apache);
}

#endif /* defined MP_IO_TIE_PERLIO */





