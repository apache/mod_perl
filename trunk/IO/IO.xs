#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifndef SvCLASS
#define SvCLASS(o) HvNAME(SvSTASH(SvRV(o)))
#endif

bool ApacheIO_open(SV *obj, SV *sv)
{
    PerlIO *IOp = Nullfp;
    GV *gv = (GV*)SvRV(obj);
    STRLEN len;
    char *filename = SvPV(sv,len);

    return do_open(gv, filename, len, FALSE, 0, 0, IOp); 
}

SV *ApacheIO_new(char *class)
{
    SV *RETVAL = sv_newmortal();
    GV *gv = newGVgen(class);
    HV *stash = GvSTASH(gv);

    sv_setsv(RETVAL, sv_bless(sv_2mortal(newRV((SV*)gv)), stash));
    (void)hv_delete(stash, GvNAME(gv), GvNAMELEN(gv), G_DISCARD);
    return RETVAL;
}

MODULE = Apache::IO		PACKAGE = Apache::IO    PREFIX = ApacheIO_

PROTOTYPES: DISABLE

void
ApacheIO_new(class, filename=Nullsv)
    char *class
    SV *filename

    PREINIT:
    SV *RETVAL;

    PPCODE:
    RETVAL = ApacheIO_new(class);
    if(filename) {
	if(!ApacheIO_open(RETVAL, filename))
	    XSRETURN_UNDEF;
    }
    XPUSHs(RETVAL);

bool
ApacheIO_open(self, filename)
    SV *self
    SV *filename

void
ApacheIO_tmpfile(self)
    SV *self

    PREINIT:
    PerlIO *fp = PerlIO_tmpfile();
    char *class = SvROK(self) ? SvCLASS(self) : SvPV(self,na);
    SV *RETVAL = ApacheIO_new(class);

    PPCODE:
    if(!do_open((GV*)SvRV(RETVAL), "+>&", 3, FALSE, 0, 0, fp))
        XSRETURN_UNDEF;
    else
        XPUSHs(RETVAL);

void
ApacheIO_close(self)
    SV *self
    
    ALIAS:
    Apache::IO::DESTROY = 1

    CODE:
    do_close((GV*)SvRV(self), TRUE);



