#ifndef MODPERL_INTERP_H
#define MODPERL_INTERP_H

modperl_interp_t *modperl_interp_new(ap_pool_t *p,
                                     modperl_interp_pool_t *mip,
                                     PerlInterpreter *perl);

void modperl_interp_destroy(modperl_interp_t *interp);

ap_status_t modperl_interp_cleanup(void *data);

modperl_interp_t *modperl_interp_get(server_rec *s);

ap_status_t modperl_interp_unselect(void *data);

int modperl_interp_select(request_rec *r);


void modperl_interp_pool_init(server_rec *s, ap_pool_t *p,
                              PerlInterpreter *perl);

ap_status_t modperl_interp_pool_destroy(void *data);

void modperl_interp_pool_add(modperl_interp_pool_t *mip,
                             modperl_interp_t *interp);

void modperl_interp_pool_remove(modperl_interp_pool_t *mip,
                                modperl_interp_t *interp);

#endif /* MODPERL_INTERP_H */
