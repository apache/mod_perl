#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

bool ApacheIO_open(SV *obj, SV *sv)
{
    PerlIO *IOp = Nullfp;
    GV *gv = (GV*)SvRV(obj);
    STRLEN len;
    char *filename = SvPV(sv,len);

    return do_open(gv, filename, len, FALSE, 0, 0, IOp); 
}

MODULE = Apache::IO		PACKAGE = Apache::IO    PREFIX = ApacheIO_

PROTOTYPES: DISABLE

void
ApacheIO_new(class, filename=Nullsv)
    char *class
    SV *filename

    PREINIT:
    SV *RETVAL = sv_newmortal();
    GV *gv = newGVgen("Apache::IO");
    HV *stash = GvSTASH(gv);

    PPCODE:
    sv_setsv(RETVAL, sv_bless(sv_2mortal(newRV((SV*)gv)), stash));
    (void)hv_delete(stash, GvNAME(gv), GvNAMELEN(gv), G_DISCARD);
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
ApacheIO_close(self)
    SV *self
    
    ALIAS:
    Apache::IO::DESTROY = 1

    CODE:
    do_close((GV*)SvRV(self), TRUE);



