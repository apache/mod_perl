#include "modperl_largefiles.h"

#include "mod_perl.h"
#include "apr_perlio.h"

#if defined(PERLIO_LAYERS) && defined(PERLIO_K_MULTIARG) /* 5.7.2+ */

/**********************************************************************
 * The PerlIO APR layer.
 * The PerlIO API is documented in perliol.pod.
 **********************************************************************/

/*
 * APR::PerlIO implements a PerlIO layer using apr_file_io as the core.
 */

/*
 * XXX: Since we cannot snoop on the internal apr_file_io buffer
 * currently the IO is not buffered on the Perl side so every read
 * requests a char at a time, which is slow. Consider copying the
 * relevant code from PerlIOBuf to implement our own buffer, similar
 * to what PerlIOBuf does or push :perlio layer on top of this layer
 */

typedef struct {
    struct _PerlIO base;
    apr_file_t *file;
    apr_pool_t *pool;
} PerlIOAPR;

static IV PerlIOAPR_pushed(pTHX_ PerlIO *f, const char *mode,
                           SV *arg, PerlIO_funcs *tab)
{
    IV code = PerlIOBase_pushed(aTHX_ f, mode, arg, tab);
    if (*PerlIONext(f)) {
        /* XXX: not sure if we can do anything here, but see
         * PerlIOUnix_pushed for things that it does
         */
    }
    return code;
}

static PerlIO *PerlIOAPR_open(pTHX_ PerlIO_funcs *self,
                              PerlIO_list_t *layers, IV n,
                              const char *mode, int fd, int imode,
                              int perm, PerlIO *f, int narg, SV **args)
{
    SV *arg = (narg > 0) ? *args : PerlIOArg;
    PerlIOAPR *st;
    const char *path;
    apr_int32_t apr_flag;
    apr_status_t rc;
    SV *sv;
    
    if (!(SvROK(arg) || SvPOK(arg))) {
        return NULL;
    }

    /* XXX: why passing only SV* for arg, check this out in PerlIO_push */
    if (!f) {
        f = PerlIO_push(aTHX_ PerlIO_allocate(aTHX), self, mode, arg);
    }
    else {
        f = PerlIO_push(aTHX_ f, self, mode, arg);
    }

    /* grab the last arg as a filepath */
    path = (const char *)SvPV_nolen(args[narg-2]);
    
    switch (*mode) {
      case 'a':
        apr_flag = APR_APPEND | APR_CREATE;
        break; 
      case 'w':
        apr_flag = APR_WRITE | APR_CREATE | APR_TRUNCATE;
        break;
      case 'r':
        apr_flag = APR_READ;
        break;
    }

    /* APR_BINARY:   we always do binary read and PerlIO is supposed
     *               to handle :crlf if any (by pushing this layer at
     *               open().
     * APR_BUFFERED: XXX, not sure if it'll be needed if we will push
     *               :perlio (== PerlIOBuf) layer on top
     */
    apr_flag |= APR_BUFFERED | APR_BINARY;
    
    st = PerlIOSelf(f, PerlIOAPR);

    /* XXX: can't reuse a wrapper mp_xs_sv2_APR__Pool */
    /* XXX: should probably add checks on pool validity in all other callbacks */
    sv = args[narg-1];
    if (SvROK(sv) && (SvTYPE(SvRV(sv)) == SVt_PVMG)) {
        st->pool = (apr_pool_t *)SvIV((SV*)SvRV(sv));
    }
    else {
        Perl_croak(aTHX_ "argument is not a blessed reference "
                   "(expecting an APR::Pool  derived object)");
    }
    
    rc = apr_file_open(&st->file, path, apr_flag, APR_OS_DEFAULT, st->pool);

#ifdef PERLIO_APR_DEBUG
    Perl_warn(aTHX_ "PerlIOAPR_open obj=0x%lx, file=0x%lx, name=%s, rc=%d\n",
              (unsigned long)f, (unsigned long)st->file,
              path ? path : "(UNKNOWN)", rc);
#endif

    if (rc != APR_SUCCESS) {
        PerlIO_pop(aTHX_ f);
        return NULL;
    }

    PerlIOBase(f)->flags |= PERLIO_F_OPEN;
    return f;
}

static IV PerlIOAPR_fileno(pTHX_ PerlIO *f)
{
    /* apr_file_t* is an opaque struct, so fileno is not available
     * -1 in this case indicates that the layer cannot provide fileno
     */
    return -1;
}

static PerlIO *PerlIOAPR_dup(pTHX_ PerlIO *f, PerlIO *o,
                             CLONE_PARAMS *param, int flags)
{
    apr_status_t rc;
 
    if ((f = PerlIOBase_dup(aTHX_ f, o, param, flags))) {
        PerlIOAPR *fst = PerlIOSelf(f, PerlIOAPR);
        PerlIOAPR *ost = PerlIOSelf(o, PerlIOAPR);

        rc = apr_file_dup(&fst->file, ost->file, ost->pool);

#ifdef PERLIO_APR_DEBUG
        Perl_warn(aTHX_ "PerlIOAPR_dup obj=0x%lx, "
                        "file=0x%lx => 0x%lx, rc=%d\n",
                  (unsigned long)f,
                  (unsigned long)ost->file,
                  (unsigned long)fst->file, rc);
#endif

        if (rc == APR_SUCCESS) {
            fst->pool = ost->pool;
            return f;
        }
    }

    return NULL;
}

static SSize_t PerlIOAPR_read(pTHX_ PerlIO *f, void *vbuf, Size_t count)
{
    PerlIOAPR *st = PerlIOSelf(f, PerlIOAPR);
    apr_status_t rc;

    rc = apr_file_read(st->file, vbuf, &count);
    if (rc == APR_EOF) {
        PerlIOBase(f)->flags |= PERLIO_F_EOF;
        return count;
    }
    else if (rc != APR_SUCCESS) {
#ifdef PERLIO_APR_DEBUG
        /* XXX: need to figure way to map APR errno to normal errno,
         * so we can use SETERRNO to make the apr errors available to
         * Perl's $!  */
        Perl_croak(aTHX_ "failed to read from file: %s",
                   modperl_apr_strerror(rc));
#endif
        PerlIOBase(f)->flags |= PERLIO_F_ERROR;
        return -1;
    }

    return count;
}

static SSize_t PerlIOAPR_write(pTHX_ PerlIO *f, const void *vbuf, Size_t count)
{
    PerlIOAPR *st = PerlIOSelf(f, PerlIOAPR);
    apr_status_t rc;

#if 0    
     Perl_warn(aTHX_ "in write: count %d, %s\n",
               (int)count, (char*) vbuf);
#endif
    
    rc = apr_file_write(st->file, vbuf, &count);
    if (rc == APR_SUCCESS) {
        return (SSize_t) count;
    }

    PerlIOBase(f)->flags |= PERLIO_F_ERROR;
    return (SSize_t) -1;
}

static IV PerlIOAPR_flush(pTHX_ PerlIO *f)
{
    PerlIOAPR *st = PerlIOSelf(f, PerlIOAPR);
    apr_status_t rc;

    rc = apr_file_flush(st->file);
    if (rc == APR_SUCCESS) {
        return 0;
    }

    PerlIOBase(f)->flags |= PERLIO_F_ERROR;
    return -1;
}

static IV PerlIOAPR_seek(pTHX_ PerlIO *f, Off_t offset, int whence)
{
    PerlIOAPR *st = PerlIOSelf(f, PerlIOAPR);
    apr_seek_where_t where;
    apr_status_t rc;
    apr_off_t seek_offset = 0;

#if MP_LARGE_FILES_CONFLICT
    if (offset != 0) {
        Perl_croak(aTHX_ "PerlIO::APR::seek with non-zero offset"
                   "is not supported with Perl built w/ -Duselargefiles"
                   " and APR w/o largefiles support");
    }
#else
    seek_offset = offset;
#endif

    /* Flush the fill buffer */
    if (PerlIO_flush(f) != 0) {
        return -1;
    }
        
    switch(whence) {
      case 0:
        where = APR_SET;
        break;
      case 1:
        where = APR_CUR;
        break;
      case 2:
        where = APR_END;
        break;
    }

    rc = apr_file_seek(st->file, where, &seek_offset);
    if (rc == APR_SUCCESS) {
        return 0;
    }

    return -1;
}

static Off_t PerlIOAPR_tell(pTHX_ PerlIO *f)
{
    PerlIOAPR *st = PerlIOSelf(f, PerlIOAPR);
    apr_off_t offset = 0;
    apr_status_t rc;
    
    rc = apr_file_seek(st->file, APR_CUR, &offset);
    if (rc == APR_SUCCESS) {
        return (Off_t) offset;
    }

    return (Off_t) -1;
}

static IV PerlIOAPR_close(pTHX_ PerlIO *f)
{
    PerlIOAPR *st = PerlIOSelf(f, PerlIOAPR);
    IV code = PerlIOBase_close(aTHX_ f);
    apr_status_t rc;

#ifdef PERLIO_APR_DEBUG
    const char *new_path = NULL;
    apr_os_file_t os_file;

    if (!PL_dirty) {
        /* if this is called during perl_destruct we are in trouble */
        apr_file_name_get(&new_path, st->file);
    }

    rc = apr_os_file_get(&os_file, st->file); 
    if (rc != APR_SUCCESS) {
        Perl_croak(aTHX_ "filedes retrieval failed!");
    }

    Perl_warn(aTHX_ "PerlIOAPR_close obj=0x%lx, file=0x%lx, fd=%d, name=%s\n",
              (unsigned long)f, (unsigned long)st->file, os_file,
              new_path ? new_path : "(UNKNOWN)");
#endif

    if (PL_dirty) {
        /* there should not be any PerlIOAPR handles open
         * during perl_destruct
         */
        Perl_warn(aTHX_ "leaked PerlIOAPR handle 0x%lx",
                  (unsigned long)f);
        return -1;
    }

    rc = apr_file_flush(st->file);
    if (rc != APR_SUCCESS) {
        return -1;
    }

    rc = apr_file_close(st->file);
    if (rc != APR_SUCCESS) {
        return -1;
    }

    return code;
}

#if 0 /* we may use it if the buffering will be done at this layer */

static IV PerlIOAPR_fill(pTHX_ PerlIO *f)
{
    PerlIOAPR *st = PerlIOSelf(f, PerlIOAPR);
    apr_status_t rc;
    SSize_t avail;
    Size_t count = st->base.bufsiz;

    if (!st->base.buf) {
        PerlIO_get_base(f);  /* allocate via vtable */
    }
        
#if 0
     Perl_warn(aTHX_ "ask to fill %d chars\n", count);
#endif

    rc = apr_file_read(st->file, st->base.ptr, &count);
    if (rc != APR_SUCCESS) {
        PerlIOBase(f)->flags |= PERLIO_F_ERROR;
        return -1;
    }

#if 0    
     Perl_warn(aTHX_ "got to fill %d chars\n", count);
#endif

    avail = count; /* apr_file_read() sets how many chars were read in count */
    if (avail <= 0) {
        if (avail == 0) {
            PerlIOBase(f)->flags |= PERLIO_F_EOF;
        }
        else {
            PerlIOBase(f)->flags |= PERLIO_F_ERROR;
        }
        
        return -1;
    }
    st->base.end = st->base.buf + avail;

    /* indicate that the buffer this layer currently holds unconsumed
       data read from layer below. */
    PerlIOBase(f)->flags |= PERLIO_F_RDBUF;

    return 0;
}

#endif

static IV PerlIOAPR_eof(pTHX_ PerlIO *f)
{
    PerlIOAPR *st = PerlIOSelf(f, PerlIOAPR);
    apr_status_t rc;

    rc = apr_file_eof(st->file);
    switch (rc) {
      case APR_EOF:
        return 1;
      default:
        return 0;
    }

    return -1;
}

/* 5.8.0 doesn't export PerlIOBase_noop_fail, so we duplicate it here */
static IV PerlIOAPR_noop_fail(pTHX_ PerlIO *f)
{
    return -1;
}

static PerlIO_funcs PerlIO_APR = {
    sizeof(PerlIO_funcs),
    "APR",
    sizeof(PerlIOAPR),
    PERLIO_K_MULTIARG,
    PerlIOAPR_pushed,
    PerlIOBase_popped,
    PerlIOAPR_open,
    PerlIOBase_binmode,         /* binmode() is handled by :crlf */
    NULL,                       /* no getarg needed */
    PerlIOAPR_fileno,
    PerlIOAPR_dup,
    PerlIOAPR_read,
    PerlIOBase_unread,
    PerlIOAPR_write,
    PerlIOAPR_seek, 
    PerlIOAPR_tell,
    PerlIOAPR_close,
    PerlIOAPR_flush,            /* flush */
    PerlIOAPR_noop_fail,        /* fill */
    PerlIOAPR_eof,
    PerlIOBase_error,
    PerlIOBase_clearerr,
    PerlIOBase_setlinebuf,
    NULL,                       /* get_base */
    NULL,                       /* get_bufsiz */
    NULL,                       /* get_ptr */
    NULL,                       /* get_cnt */
    NULL,                       /* set_ptrcnt */
};

void apr_perlio_init(pTHX)
{
    APR_REGISTER_OPTIONAL_FN(apr_perlio_apr_file_to_PerlIO);
    APR_REGISTER_OPTIONAL_FN(apr_perlio_apr_file_to_glob);

    PerlIO_define_layer(aTHX_ &PerlIO_APR);
}


/* ***** End of PerlIOAPR tab ***** */


/* ***** PerlIO <=> apr_file_t helper functions ***** */

PerlIO *apr_perlio_apr_file_to_PerlIO(pTHX_ apr_file_t *file, apr_pool_t *pool,
                                      apr_perlio_hook_e type)
{
    char *mode;
    const char *layers = ":APR";
    PerlIOAPR *st;
    PerlIO *f = PerlIO_allocate(aTHX);

    if (!f) {
        Perl_croak(aTHX_ "Failed to allocate PerlIO struct");
    }
    
    switch (type) {
      case APR_PERLIO_HOOK_WRITE:
        mode = "w";
        break;
      case APR_PERLIO_HOOK_READ:
        mode = "r";
        break;
    };
    
    PerlIO_apply_layers(aTHX_ f, mode, layers);
    if (!f) {
        Perl_croak(aTHX_ "Failed to apply the ':APR' layer");
    }

    st = PerlIOSelf(f, PerlIOAPR);

#ifdef PERLIO_APR_DEBUG    
    {
        apr_status_t rc;
        apr_os_file_t os_file;

        /* convert to the OS representation of file */
        rc = apr_os_file_get(&os_file, file); 
        if (rc != APR_SUCCESS) {
            croak("filedes retrieval failed!");
        }
    
        Perl_warn(aTHX_ "converting to PerlIO fd %d, mode '%s'\n",
                  os_file, mode);
    }
#endif

    st->pool = pool;
    st->file = file;
    PerlIOBase(f)->flags |= PERLIO_F_OPEN;

    return f;
}

static SV *apr_perlio_PerlIO_to_glob(pTHX_ PerlIO *pio, apr_perlio_hook_e type)
{
    /* XXX: modperl_perl_gensym() cannot be used outside of httpd */
    SV *retval = modperl_perl_gensym(aTHX_ "APR::PerlIO"); 
    GV *gv = (GV*)SvRV(retval); 

    gv_IOadd(gv); 

    switch (type) {
      case APR_PERLIO_HOOK_WRITE:
          /* if IoIFP() is not assigned to it'll be never closed, see
           * Perl_io_close() */
        IoIFP(GvIOp(gv)) = IoOFP(GvIOp(gv)) = pio;
        IoFLAGS(GvIOp(gv)) |= IOf_FLUSH;
        IoTYPE(GvIOp(gv)) = IoTYPE_WRONLY;
        break;
      case APR_PERLIO_HOOK_READ:
        IoIFP(GvIOp(gv)) = pio;
        IoTYPE(GvIOp(gv)) = IoTYPE_RDONLY;
        break;
    };

    return sv_2mortal(retval);
}

SV *apr_perlio_apr_file_to_glob(pTHX_ apr_file_t *file, apr_pool_t *pool,
                                apr_perlio_hook_e type)
{
    return apr_perlio_PerlIO_to_glob(aTHX_
                                     apr_perlio_apr_file_to_PerlIO(aTHX_ file,
                                                                   pool, type),
                                     type);
}

#else /* NOT PERLIO_LAYERS (5.6.1) */

static FILE *apr_perlio_apr_file_to_FILE(pTHX_ apr_file_t *file,
                                         apr_perlio_hook_e type)
{
    FILE *retval;
    char *mode;
    int fd;
    apr_os_file_t os_file;
    apr_status_t rc;
    
    switch (type) {
      case APR_PERLIO_HOOK_WRITE:
        mode = "w";
        break;
      case APR_PERLIO_HOOK_READ:
        mode = "r";
        break;
    };

    /* convert to the OS representation of file */
    rc = apr_os_file_get(&os_file, file); 
    if (rc != APR_SUCCESS) {
        Perl_croak(aTHX_ "filedes retrieval failed!");
    }

#ifdef PERLIO_APR_DEBUG
    Perl_warn(aTHX_ "converting fd %d\n", os_file);
#endif

    /* let's try without the dup, it seems to work fine:

       fd = PerlLIO_dup(os_file);
       Perl_warn(aTHX_ "fd old: %d, new %d\n", os_file, fd);
       if (!(retval = PerlIO_fdopen(fd, mode))) { 
       ...
       }

       in any case if we later decide to dup, remember to:

       apr_file_close(file);

       after PerlIO_fdopen() or that fh will be leaked
       
    */

    if (!(retval = PerlIO_fdopen(os_file, mode))) { 
        PerlLIO_close(fd);
        Perl_croak(aTHX_ "fdopen failed!");
    } 

    return retval;
}

SV *apr_perlio_apr_file_to_glob(pTHX_ apr_file_t *file, apr_pool_t *pool,
                                apr_perlio_hook_e type)
{
    /* XXX: modperl_perl_gensym() cannot be used outside of httpd */
    SV *retval = modperl_perl_gensym(aTHX_ "APR::PerlIO"); 
    GV *gv = (GV*)SvRV(retval); 

    gv_IOadd(gv); 

    switch (type) {
      case APR_PERLIO_HOOK_WRITE:
        IoIFP(GvIOp(gv)) = IoOFP(GvIOp(gv)) =
            apr_perlio_apr_file_to_FILE(aTHX_ file, type);
        IoFLAGS(GvIOp(gv)) |= IOf_FLUSH;
        IoTYPE(GvIOp(gv)) = IoTYPE_WRONLY;
        break;
      case APR_PERLIO_HOOK_READ:
        IoIFP(GvIOp(gv)) = apr_perlio_apr_file_to_FILE(aTHX_ file, type);
        IoTYPE(GvIOp(gv)) = IoTYPE_RDONLY;
        break;
    };
  
    return sv_2mortal(retval);
}

void apr_perlio_init(pTHX)
{
    APR_REGISTER_OPTIONAL_FN(apr_perlio_apr_file_to_glob);
}

#endif /* PERLIO_LAYERS */

