#ifndef MODPERL_CONFIG_H
#define MODPERL_CONFIG_H

void *modperl_config_dir_create(apr_pool_t *p, char *dir);

void *modperl_config_dir_merge(apr_pool_t *p, void *basev, void *addv);

modperl_config_srv_t *modperl_config_srv_new(apr_pool_t *p);

modperl_config_dir_t *modperl_config_dir_new(apr_pool_t *p);

modperl_config_req_t *modperl_config_req_new(request_rec *r);

void *modperl_config_srv_create(apr_pool_t *p, server_rec *s);

void *modperl_config_srv_merge(apr_pool_t *p, void *basev, void *addv);

char **modperl_config_srv_argv_init(modperl_config_srv_t *scfg, int *argc);

#define modperl_config_srv_argv_push(arg) \
    *(const char **)apr_array_push(scfg->argv) = arg

#define modperl_config_req_init(r, rcfg) \
    if (!rcfg) { \
        rcfg = modperl_config_req_new(r); \
        ap_set_module_config(r->request_config, &perl_module, rcfg); \
    }

#define modperl_config_req_get(r) \
 (r ? (modperl_config_req_t *) \
          ap_get_module_config(r->request_config, &perl_module) : NULL)

#define MP_dRCFG \
   modperl_config_req_t *rcfg = modperl_config_req_get(r)

#define modperl_config_dir_get(r) \
      (r ? (modperl_config_dir_t *) \
              ap_get_module_config(r->per_dir_config, &perl_module) : NULL)

#define modperl_config_dir_get_defaults(s) \
      (modperl_config_dir_t *) \
          ap_get_module_config(s->lookup_defaults, &perl_module)

#define MP_dDCFG \
   modperl_config_dir_t *dcfg = modperl_config_dir_get(r)

#define modperl_config_srv_get(s) \
 (modperl_config_srv_t *) \
          ap_get_module_config(s->module_config, &perl_module)

#define MP_dSCFG(s) \
   modperl_config_srv_t *scfg = modperl_config_srv_get(s)

#ifdef USE_ITHREADS
#   define MP_dSCFG_dTHX \
    dTHXa(scfg->mip->parent->perl); \
    PERL_SET_CONTEXT(aTHX)
#else
#   define MP_dSCFG_dTHX dTHXa(scfg->perl)
#endif

int modperl_config_apply_PerlModule(server_rec *s,
                                    modperl_config_srv_t *scfg,
                                    PerlInterpreter *perl, apr_pool_t *p);

int modperl_config_apply_PerlRequire(server_rec *s,
                                     modperl_config_srv_t *scfg,
                                     PerlInterpreter *perl, apr_pool_t *p);

#endif /* MODPERL_CONFIG_H */
