#ifndef MODPERL_HANDLER_H
#define MODPERL_HANDLER_H

modperl_handler_t *modperl_handler_new(apr_pool_t *p, const char *name);

modperl_handler_t *modperl_handler_dup(apr_pool_t *p,
                                       modperl_handler_t *h);

void modperl_handler_make_args(pTHX_ AV **avp, ...);

MpAV **modperl_handler_lookup_handlers(modperl_config_dir_t *dcfg,
                                       modperl_config_srv_t *scfg,
                                       modperl_config_req_t *rcfg,
                                       int type, int idx,
                                       const char **desc);

#endif /* MODPERL_HANDLER_H */
