#include "modperl_largefiles.h"

#include "mod_perl.h"
#include "apr_perlio.h"

/* XXX: prerequisites to have things working
 * PerlIO_flush patch : perl 5.7.2 patch 13978 is required
 * dup() : apr cvs date: 2001/12/06 13:43:45
 *
 * XXX: it's not enough to check for PERLIO_LAYERS, some functionality
 * and bug fixes were added only in the late 5.7.2, whereas
 * PERLIO_LAYERS is available in 5.7.1
 */

#if defined(PERLIO_LAYERS) && defined(PERLIO_K_MULTIARG) /* 5.7.2+ */

/**********************************************************************
 * The PerlIO APR layer.
 * The PerlIO API is documented in perliol.pod.
 **********************************************************************/

typedef struct {
    PerlIOBuf base;    /* PerlIOBuf stuff */
    apr_file_t *file;
    apr_pool_t *pool;
} PerlIOAPR;

/* clean up any structures linked from PerlIOAPR. a layer can be
 * popped without being closed if the program is dynamically managing
 * layers on the stream.
 */
static IV PerlIOAPR_popped(pTHX_ PerlIO *f)
{
    /* PerlIOAPR *st = PerlIOSelf(f, PerlIOAPR); */

    return 0;
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
    
    st = PerlIOSelf(f, PerlIOAPR);

    sv = args[narg-1];
    /* XXX: modperl_sv2pool cannot be used outside of httpd */
    st->pool = modperl_sv2pool(aTHX_ sv);
  
    rc = apr_file_open(&st->file, path, apr_flag, APR_OS_DEFAULT, st->pool);

#ifdef PERLIO_APR_DEBUG
    Perl_warn(aTHX_ "PerlIOAPR_open obj=0x%lx, file=0x%lx, name=%s, rc=%d\n",
              (unsigned long)f, (unsigned long)st->file,
              path ? path : "(UNKNOWN)", rc);
#endif

    if (rc != APR_SUCCESS) {
        PerlIOBase(f)->flags |= PERLIO_F_ERROR;
        return NULL;
    }

    PerlIOBase(f)->flags |= PERLIO_F_OPEN;
    return f;
}

static IV PerlIOAPR_fileno(pTHX_ PerlIO *f)
{
    /* apr_file_t* is an opaque struct, so fileno is not available */
    /* XXX: this -1 workaround should be documented in perliol.pod */
    /* see: http://www.xray.mpe.mpg.de/mailing-lists/perl5-porters/2001-11/thrd21.html#02040 */
    /* http://www.xray.mpe.mpg.de/mailing-lists/perl5-porters/2001-12/threads.html#00217 */
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

    return (SSize_t) -1;
}

static IV PerlIOAPR_seek(pTHX_ PerlIO *f, Off_t offset, int whence)
{
    PerlIOAPR *st = PerlIOSelf(f, PerlIOAPR);
    apr_seek_where_t where;
    apr_status_t rc;
    IV code;
    
    /* Flush the fill buffer */
    code = PerlIOBuf_flush(aTHX_ f);
    if (code != 0) {
        return code;
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

    rc = apr_file_seek(st->file, where, (apr_off_t *)&offset);
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
    if (!PL_dirty) {
        /* if this is called during perl_destruct we are in trouble */
        apr_file_name_get(&new_path, st->file);
    }

    Perl_warn(aTHX_ "PerlIOAPR_close obj=0x%lx, file=0x%lx, name=%s\n",
              (unsigned long)f, (unsigned long)st->file,
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

static IV PerlIOAPR_flush(pTHX_ PerlIO *f)
{
    PerlIOAPR *st = PerlIOSelf(f, PerlIOAPR);
    apr_status_t rc;

    rc = apr_file_flush(st->file);
    if (rc == APR_SUCCESS) {
        return 0;
    }

    return -1;
}

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
        /* XXX */
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

static PerlIO_funcs PerlIO_APR = {
    "APR",
    sizeof(PerlIOAPR),
    PERLIO_K_BUFFERED | PERLIO_K_FASTGETS | PERLIO_K_MULTIARG,
    PerlIOBase_pushed,
    PerlIOAPR_popped,
    PerlIOAPR_open,
    NULL,  /* no getarg needed */
    PerlIOAPR_fileno,
    PerlIOAPR_dup,
    PerlIOBuf_read,
    PerlIOBuf_unread,
    PerlIOAPR_write,
    PerlIOAPR_seek, 
    PerlIOAPR_tell,
    PerlIOAPR_close,
    PerlIOAPR_flush,
    PerlIOAPR_fill,
    PerlIOAPR_eof,
    PerlIOBase_error,
    PerlIOBase_clearerr,
    PerlIOBase_setlinebuf,
    PerlIOBuf_get_base,
    PerlIOBuf_bufsiz,
    PerlIOBuf_get_ptr,
    PerlIOBuf_get_cnt,
    PerlIOBuf_set_ptrcnt,
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
    PerlIO *f = PerlIO_allocate(aTHX);
    if (!f) {
        return NULL;
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

    if (f) {
        PerlIOAPR *st = PerlIOSelf(f, PerlIOAPR);

        /* XXX: should we dup first? the timeout could close the fh! */
        st->pool = pool;
        st->file = file;
        PerlIOBase(f)->flags |= PERLIO_F_OPEN;

        return f;
    }

    return NULL;
}

static SV *apr_perlio_PerlIO_to_glob(pTHX_ PerlIO *pio, apr_perlio_hook_e type)
{
    /* XXX: modperl_perl_gensym() cannot be used outside of httpd */
    SV *retval = modperl_perl_gensym(aTHX_ "APR::PerlIO"); 
    GV *gv = (GV*)SvRV(retval); 

    gv_IOadd(gv); 

    switch (type) {
      case APR_PERLIO_HOOK_WRITE:
        IoOFP(GvIOp(gv)) = pio;
        IoFLAGS(GvIOp(gv)) |= IOf_FLUSH;
        break;
      case APR_PERLIO_HOOK_READ:
        IoIFP(GvIOp(gv)) = pio;
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

#elif !defined(PERLIO_LAYERS) && !defined(WIN32) /* NOT PERLIO_LAYERS (5.6.1) */

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
        croak("filedes retrieval failed!");
    }
    
    fd = PerlLIO_dup(os_file); 
    /* Perl_warn(aTHX_ "fd old: %d, new %d\n", os_file, fd); */
    
    if (!(retval = PerlIO_fdopen(fd, mode))) { 
        PerlLIO_close(fd);
        croak("fdopen failed!");
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
        IoOFP(GvIOp(gv)) = apr_perlio_apr_file_to_FILE(aTHX_ file, type);
        IoFLAGS(GvIOp(gv)) |= IOf_FLUSH;
        break;
      case APR_PERLIO_HOOK_READ:
        IoIFP(GvIOp(gv)) = apr_perlio_apr_file_to_FILE(aTHX_ file, type);
        break;
    };
  
    return sv_2mortal(retval);
}

void apr_perlio_init(pTHX)
{
    APR_REGISTER_OPTIONAL_FN(apr_perlio_apr_file_to_glob);
}

#else

void apr_perlio_init(pTHX)
{
    Perl_croak(aTHX_ "APR::PerlIO not usable with this version of Perl");
}

#endif /* PERLIO_LAYERS */

