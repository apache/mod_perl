#include "mod_perl.h"

/* this module contains mod_perl small tweaks to the Perl runtime
 * others (larger tweaks) are in their own modules, e.g. modperl_env.c
 */

void modperl_perl_init_ids(pTHX)
{
    sv_setiv(GvSV(gv_fetchpv("$", TRUE, SVt_PV)), (I32)getpid());

#ifndef WIN32
    PL_uid  = (int)getuid(); 
    PL_euid = (int)geteuid(); 
    PL_gid  = (int)getgid(); 
    PL_egid = (int)getegid(); 
    MP_TRACE_g(MP_FUNC, 
               "uid=%d, euid=%d, gid=%d, egid=%d\n",
               PL_uid, PL_euid, PL_gid, PL_egid);
#endif
}
