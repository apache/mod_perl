#ifndef MODPERL_INTERP_H
#define MODPERL_INTERP_H

modperl_interp_t *modperl_interp_new(ap_pool_t *p,
                                     modperl_interp_t *parent);

modperl_interp_t *modperl_interp_get(server_rec *s);

void modperl_interp_pool_init(server_rec *s, ap_pool_t *p,
                              PerlInterpreter *perl);

ap_status_t modperl_interp_unselect(void *data);

int modperl_interp_select(request_rec *r);

#endif /* MODPERL_INTERP_H */
