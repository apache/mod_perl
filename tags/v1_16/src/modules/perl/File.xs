#ifdef MOD_PERL
#include "mod_perl.h"
#else
#include "modules/perl/mod_perl.h"
#endif

#define ap_fopen(r, name, mode) \
        ap_pfopen(r->pool, name, mode)
#define ap_fclose(r, fd) \
        ap_pfclose(r->pool, fd)

#ifndef SvCLASS
#define SvCLASS(o) HvNAME(SvSTASH(SvRV(o)))
#endif

static bool ApacheFile_open(SV *obj, SV *sv)
{
    PerlIO *IOp = Nullfp;
    GV *gv = (GV*)SvRV(obj);
    STRLEN len;
    char *filename = SvPV(sv,len);

    return do_open(gv, filename, len, FALSE, 0, 0, IOp); 
}

static SV *ApacheFile_new(char *class)
{
    SV *RETVAL = sv_newmortal();
    GV *gv = newGVgen(class);
    HV *stash = GvSTASH(gv);

    sv_setsv(RETVAL, sv_bless(sv_2mortal(newRV((SV*)gv)), stash));
    (void)hv_delete(stash, GvNAME(gv), GvNAMELEN(gv), G_DISCARD);
    return RETVAL;
}

MODULE = Apache::File		PACKAGE = Apache::File    PREFIX = ApacheFile_

PROTOTYPES: DISABLE

void
ApacheFile_new(class, filename=Nullsv)
    char *class
    SV *filename

    PREINIT:
    SV *RETVAL;

    PPCODE:
    RETVAL = ApacheFile_new(class);
    if(filename) {
	if(!ApacheFile_open(RETVAL, filename))
	    XSRETURN_UNDEF;
    }
    XPUSHs(RETVAL);

bool
ApacheFile_open(self, filename)
    SV *self
    SV *filename

void
ApacheFile_tmp(self)
    SV *self

    PREINIT:
    PerlIO *fp = PerlIO_tmpfile();
    char *class = SvROK(self) ? SvCLASS(self) : SvPV(self,na);
    SV *RETVAL = ApacheFile_new(class);

    PPCODE:
    if(!do_open((GV*)SvRV(RETVAL), "+>&", 3, FALSE, 0, 0, fp))
        XSRETURN_UNDEF;
    else
        XPUSHs(RETVAL);

bool
ApacheFile_close(self)
    SV *self
    
    CODE:
    RETVAL = do_close((GV*)SvRV(self), TRUE);

    OUTPUT:
    RETVAL

MODULE = Apache::File  PACKAGE = Apache   PREFIX = ap_

PROTOTYPES: DISABLE

int
ap_set_content_length(r, clength=r->finfo.st_size)
    Apache r
    long clength

void
ap_set_last_modified(r, mtime=0)
    Apache r
    time_t mtime

    CODE:
    if(mtime) ap_update_mtime(r, mtime);
    ap_set_last_modified(r);

void
ap_set_etag(r)
    Apache r

int
ap_meets_conditions(r)
    Apache r

time_t
ap_update_mtime(r, dependency_mtime=r->finfo.st_mtime)
    Apache r
    time_t dependency_mtime

int
ap_discard_request_body(r)
    Apache r

FILE *
ap_fopen(r, name, mode="r")
    Apache r
    const char *name
    const char *mode

int
ap_fclose(r, fd)
    Apache r
    FILE *fd
