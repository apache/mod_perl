
#include "mod_perl.h"
#include "apr_perlio.h"

/* XXX: prerequisites to have things working
 * open(): perl 5.7.2 patch 13534 is required
 * dup() : apr cvs date: 2001/12/06 13:43:45
 * tell(): the patch isn't in yet.
 *
 * XXX: it's not enough to check for PERLIO_LAYERS, some functionality
 * and bug fixes were added only in the late 5.7.2, whereas
 * PERLIO_LAYERS is available in 5.7.1
 */

#ifdef PERLIO_LAYERS /* 5.7.2+ */

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
static IV PerlIOAPR_popped(PerlIO *f)
{
    PerlIOAPR *st = PerlIOSelf(f, PerlIOAPR);

    return 0;
}

static PerlIO *PerlIOAPR_open(pTHX_ PerlIO_funcs *self,
                              PerlIO_list_t *layers, IV n,
                              const char *mode, int fd, int imode,
                              int perm, PerlIO *f, int narg, SV **args)
{
    AV *av_arg;
    SV *arg = (narg > 0) ? *args : PerlIOArg;
    PerlIOAPR *st;
    const char *path;
    apr_int32_t apr_flag;
    int len;
    apr_status_t rc;
    SV *sv;
    
    if ( !(SvROK(arg) || SvPOK(arg)) ) {
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
    st->pool = modperl_sv2pool(aTHX_ sv);
  
    rc = apr_file_open(&st->file, path, apr_flag, APR_OS_DEFAULT, st->pool);
    if (rc != APR_SUCCESS) {
        PerlIOBase(f)->flags |= PERLIO_F_ERROR;
        return NULL;
    }
    else {
        PerlIOBase(f)->flags |= PERLIO_F_OPEN;
        return f;
    }
}

static IV PerlIOAPR_fileno(PerlIO *f)
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
    Size_t count;
    apr_status_t rc;
 
    if ( (f = PerlIOBase_dup(aTHX_ f, o, param, flags)) ) {
        PerlIOAPR *fst = PerlIOSelf(f, PerlIOAPR);
        PerlIOAPR *ost = PerlIOSelf(o, PerlIOAPR);

        rc = apr_file_dup(&fst->file, ost->file, ost->pool);
        if (rc == APR_SUCCESS) {
            fst->pool = ost->pool;
            return f;
        }
    }

    return NULL;
    
}


/* currrently read is very not-optimized, since in many cases the read
 * process happens a char by char. Need to find a way to snoop on APR
 * read buffer from PerlIO, or implement our own buffering layer here
 */
static SSize_t PerlIOAPR_read(PerlIO *f, void *vbuf, Size_t count)
{
    PerlIOAPR *st = PerlIOSelf(f, PerlIOAPR);
    apr_status_t rc;
    dTHX;
    
//    fprintf(stderr, "in  read: count %d, %s\n", (int)count, (char*) vbuf);
    rc = apr_file_read(st->file, vbuf, &count);
//    fprintf(stderr, "out read: count %d, %s\n", (int)count, (char*) vbuf);
    if (rc == APR_SUCCESS) {
        return (SSize_t) count;
    }
    else {
        return (SSize_t) -1;
    }
}


static SSize_t PerlIOAPR_write(PerlIO *f, const void *vbuf, Size_t count)
{
    PerlIOAPR *st = PerlIOSelf(f, PerlIOAPR);
    apr_status_t rc;
    
//    fprintf(stderr, "in write: count %d, %s\n", (int)count, (char*) vbuf);
    rc = apr_file_write(st->file, vbuf, &count);
    if (rc == APR_SUCCESS) {
        return (SSize_t) count;
    }
    else {
        return (SSize_t) -1;
    }
}

static IV PerlIOAPR_seek(PerlIO *f, Off_t offset, int whence)
{
    PerlIOAPR *st = PerlIOSelf(f, PerlIOAPR);
    apr_seek_where_t where;
    apr_status_t rc;
    
    /* XXX: must flush before seek? */
    rc = apr_file_flush(st->file);
    if (rc != APR_SUCCESS) {
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

    rc = apr_file_seek(st->file, where, (apr_off_t *)&offset);
    if (rc == APR_SUCCESS) {
        return 0;
    }
    else {
        return -1;
    }
}

static Off_t PerlIOAPR_tell(PerlIO *f)
{
    PerlIOAPR *st = PerlIOSelf(f, PerlIOAPR);
    apr_off_t offset = 0;
    apr_status_t rc;
    
    /* this is broken, for some reason it returns 6e17 */

    rc = apr_file_seek(st->file, APR_CUR, &offset);
    if (rc == APR_SUCCESS) {
        return (Off_t) offset;
    }
    else {
        return (Off_t) -1;
    }
}

static IV PerlIOAPR_close(PerlIO *f)
{
    PerlIOAPR *st = PerlIOSelf(f, PerlIOAPR);
    IV code = PerlIOBase_close(f);
    apr_status_t rc;

    const char *new_path;
    apr_file_name_get(&new_path, st->file);
//    fprintf(stderr, "closing file %s\n", new_path);

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

static IV PerlIOAPR_flush(PerlIO *f)
{
    PerlIOAPR *st = PerlIOSelf(f, PerlIOAPR);
    apr_status_t rc;

    rc = apr_file_flush(st->file);
    if (rc == APR_SUCCESS) {
        return 0;
    }
    else {
        return -1;
    }
}

static IV PerlIOAPR_fill(PerlIO *f)
{
    return -1;
}

static IV PerlIOAPR_eof(PerlIO *f)
{
    PerlIOAPR *st = PerlIOSelf(f, PerlIOAPR);
    apr_status_t rc;

    rc = apr_file_eof(st->file);
    switch (rc) {
      case APR_SUCCESS: 
        return 0;
      case APR_EOF:
        return 1;
    }
}

static PerlIO_funcs PerlIO_APR = {
    "APR",
    sizeof(PerlIOAPR),
    PERLIO_K_BUFFERED | PERLIO_K_MULTIARG, /* XXX: document the flag in perliol.pod */
    PerlIOBase_pushed,
    PerlIOAPR_popped,
    PerlIOAPR_open,
    NULL,  /* no getarg needed */
    PerlIOAPR_fileno,
    PerlIOAPR_dup,
    PerlIOAPR_read,
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

PerlIO *apr_perlio_apr_file_to_PerlIO(pTHX_ apr_file_t *file,
                                      apr_pool_t *pool, int type)
{
    char *mode;
    const char *layers = ":APR";
    PerlIO *f = PerlIO_allocate(aTHX);

    switch (type) {
      case APR_PERLIO_HOOK_WRITE:
        mode = "w";
        break;
      case APR_PERLIO_HOOK_READ:
        mode = "r";
        break;
      default:
          /* */
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
    else {
        return NULL;
    }
}

/*
 * type: APR_PERLIO_HOOK_READ | APR_PERLIO_HOOK_WRITE
 */
static SV *apr_perlio_PerlIO_to_glob(pTHX_ PerlIO *pio, int type)
{
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
      default:
          /* */
    };

    return sv_2mortal(retval);
}

SV *apr_perlio_apr_file_to_glob(pTHX_ apr_file_t *file,
                                apr_pool_t *pool, int type)
{
    return apr_perlio_PerlIO_to_glob(aTHX_
                                     apr_perlio_apr_file_to_PerlIO(aTHX_ file, pool, type),
                                     type);
}

#else /* NOT PERLIO_LAYERS (5.6.1) */

FILE *apr_perlio_apr_file_to_FILE(pTHX_ apr_file_t *file, int type)
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
      default:
          /* */
    };

    /* convert to the OS representation of file */
    rc = apr_os_file_get(&os_file, file); 
    if (rc != APR_SUCCESS) {
	croak("filedes retrieval failed!");
    }
    
    fd = PerlLIO_dup(os_file); 
//    Perl_warn(aTHX_ "fd old: %d, new %d\n", os_file, fd);
    
    if (!(retval = PerlIO_fdopen(fd, mode))) { 
	PerlLIO_close(fd);
	croak("fdopen failed!");
    } 

    return retval;
}

/*
 * 
 * type: APR_PERLIO_HOOK_READ | APR_PERLIO_HOOK_WRITE
 */
SV *apr_perlio_apr_file_to_glob(pTHX_ apr_file_t *file,
                                apr_pool_t *pool, int type)
{
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
      default:
          /* */
    };
        
    return sv_2mortal(retval);
}

void apr_perlio_init(pTHX)
{
    APR_REGISTER_OPTIONAL_FN(apr_perlio_apr_file_to_glob);
}

#endif /* PERLIO_LAYERS */

