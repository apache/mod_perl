#ifndef MODPERL_INTERP_H
#define MODPERL_INTERP_H

void modperl_interp_init(server_rec *s, apr_pool_t *p,
                         PerlInterpreter *perl);

apr_status_t modperl_interp_cleanup(void *data);

#ifdef USE_ITHREADS

/*
 * HvPMROOT will never be used by Perl with PL_modglobal.
 * so we have stolen it as a quick way to stash the interp
 * pointer.
 */
#define MP_THX_INTERP_GET(thx) \
    (modperl_interp_t *)HvPMROOT(*Perl_Imodglobal_ptr(thx))

#define MP_THX_INTERP_SET(thx, interp) \
    HvPMROOT(*Perl_Imodglobal_ptr(thx)) = (PMOP*)interp

const char *modperl_interp_scope_desc(modperl_interp_scope_e scope);

void modperl_interp_clone_init(modperl_interp_t *interp);

modperl_interp_t *modperl_interp_new(modperl_interp_pool_t *mip,
                                     PerlInterpreter *perl);

void modperl_interp_destroy(modperl_interp_t *interp);

modperl_interp_t *modperl_interp_get(server_rec *s);

apr_status_t modperl_interp_unselect(void *data);

modperl_interp_t *modperl_interp_select(request_rec *r, conn_rec *c,
                                        server_rec *s);

#define MP_dINTERP_SELECT(r, c, s) \
    pTHX; \
    modperl_interp_t *interp = NULL; \
    interp = modperl_interp_select(r, c, s); \
    aTHX = interp->perl

#define MP_aTHX aTHX

apr_status_t modperl_interp_pool_destroy(void *data);

typedef apr_status_t (*modperl_interp_mip_walker_t)(pTHX_ 
                                                    modperl_interp_pool_t *mip,
                                                    void *data);

void modperl_interp_mip_walk(PerlInterpreter *current_perl,
                             PerlInterpreter *parent_perl,
                             modperl_interp_pool_t *mip,
                             modperl_interp_mip_walker_t walker,
                             void *data);

void modperl_interp_mip_walk_servers(PerlInterpreter *current_perl,
                                     server_rec *base_server,
                                     modperl_interp_mip_walker_t walker,
                                     void *data);
#else

#define MP_dINTERP_SELECT(r, c, s) dNOOP

#define MP_aTHX 0

#endif /* USE_ITHREADS */

#endif /* MODPERL_INTERP_H */
