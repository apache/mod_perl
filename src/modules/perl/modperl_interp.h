#ifndef MODPERL_INTERP_H
#define MODPERL_INTERP_H

void modperl_interp_init(server_rec *s, apr_pool_t *p,
                         PerlInterpreter *perl);

apr_status_t modperl_interp_cleanup(void *data);

#ifdef USE_ITHREADS
const char *modperl_interp_scope_desc(modperl_interp_scope_e scope);

modperl_interp_t *modperl_interp_new(apr_pool_t *p,
                                     modperl_interp_pool_t *mip,
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

apr_status_t modperl_interp_pool_destroy(void *data);

void modperl_interp_pool_add(modperl_interp_pool_t *mip,
                             modperl_interp_t *interp);

void modperl_interp_pool_remove(modperl_interp_pool_t *mip,
                                modperl_interp_t *interp);

#else
#define MP_dINTERP_SELECT(r, c, s) dNOOP
#endif

#endif /* MODPERL_INTERP_H */
