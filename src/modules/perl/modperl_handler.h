#ifndef MODPERL_HANDLER_H
#define MODPERL_HANDLER_H

typedef enum {
    MP_HANDLER_ACTION_GET,
    MP_HANDLER_ACTION_PUSH,
    MP_HANDLER_ACTION_SET
} modperl_handler_action_e;

#define modperl_handler_array_new(p) \
apr_array_make(p, 1, sizeof(modperl_handler_t *))

#define modperl_handler_array_push(handlers, h) \
*(modperl_handler_t **)apr_array_push(handlers) = h

#define modperl_handler_array_item(handlers, idx) \
((modperl_handler_t **)(handlers)->elts)[idx]

#define modperl_handler_array_last(handlers) \
modperl_handler_array_item(handlers, ((handlers)->nelts - 1))

modperl_handler_t *modperl_handler_new(apr_pool_t *p, const char *name);

int modperl_handler_resolve(pTHX_ modperl_handler_t **handp,
                            apr_pool_t *p, server_rec *s);

modperl_handler_t *modperl_handler_dup(apr_pool_t *p,
                                       modperl_handler_t *h);

int modperl_handler_equal(modperl_handler_t *h1, modperl_handler_t *h2);

MpAV *modperl_handler_array_merge(apr_pool_t *p, MpAV *base_a, MpAV *add_a);

void modperl_handler_make_args(pTHX_ AV **avp, ...);

MpAV **modperl_handler_lookup_handlers(modperl_config_dir_t *dcfg,
                                       modperl_config_srv_t *scfg,
                                       modperl_config_req_t *rcfg,
                                       apr_pool_t *p,
                                       int type, int idx,
                                       modperl_handler_action_e action,
                                       const char **desc);

MpAV **modperl_handler_get_handlers(request_rec *r, conn_rec *c,server_rec *s, 
                                    apr_pool_t *p, const char *name,
                                    modperl_handler_action_e action);

int modperl_handler_push_handlers(pTHX_ apr_pool_t *p,
                                  MpAV *handlers, SV *sv);

SV *modperl_handler_perl_get_handlers(pTHX_ MpAV **handp, apr_pool_t *p);

int modperl_handler_perl_add_handlers(pTHX_
                                      request_rec *r,
                                      conn_rec *c,
                                      server_rec *s,
                                      apr_pool_t *p,
                                      const char *name,
                                      SV *sv,
                                      modperl_handler_action_e action);

#endif /* MODPERL_HANDLER_H */
