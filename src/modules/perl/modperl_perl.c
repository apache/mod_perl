#include "mod_perl.h"

/* this module contains mod_perl small tweaks to the Perl runtime
 * others (larger tweaks) are in their own modules, e.g. modperl_env.c
 */

void modperl_perl_ids_get(modperl_perl_ids_t *ids)
{
    ids->pid  = (I32)getpid();
#ifndef WIN32
    ids->uid  = getuid();
    ids->euid = geteuid(); 
    ids->gid  = getgid(); 
    ids->gid  = getegid(); 

    MP_TRACE_g(MP_FUNC, 
               "uid=%d, euid=%d, gid=%d, egid=%d\n",
               (int)ids->uid, (int)ids->euid,
               (int)ids->gid, (int)ids->egid);
#endif
}

void modperl_perl_init_ids(pTHX_ modperl_perl_ids_t *ids)
{
    sv_setiv(GvSV(gv_fetchpv("$", TRUE, SVt_PV)), ids->pid);

#ifndef WIN32
    PL_uid  = ids->uid;
    PL_euid = ids->euid;
    PL_gid  = ids->gid;
    PL_egid = ids->egid;
#endif
}

void modperl_perl_init_ids_server(server_rec *s)
{
    modperl_perl_ids_t ids;
    modperl_perl_ids_get(&ids);
#ifdef USE_ITHREADS
     modperl_interp_mip_walk_servers(NULL, s,
                                     modperl_perl_init_ids_mip,
                                    (void*)&ids);
#else
    modperl_perl_init_ids(aTHX_ &ids);
#endif
}

#ifdef USE_ITHREADS

apr_status_t modperl_perl_init_ids_mip(pTHX_ modperl_interp_pool_t *mip,
                                       void *data)
{
    modperl_perl_init_ids(aTHX_ (modperl_perl_ids_t *)data);
    return APR_SUCCESS;
}

#endif /* USE_ITHREADS */
