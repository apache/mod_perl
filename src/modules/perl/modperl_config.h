#ifndef MODPERL_CONFIG_H
#define MODPERL_CONFIG_H

void *modperl_config_dir_create(apr_pool_t *p, char *dir);

void *modperl_config_dir_merge(apr_pool_t *p, void *basev, void *addv);

modperl_config_srv_t *modperl_config_srv_new(apr_pool_t *p);

modperl_config_dir_t *modperl_config_dir_new(apr_pool_t *p);

modperl_config_req_t *modperl_config_req_new(request_rec *r);

void *modperl_config_srv_create(apr_pool_t *p, server_rec *s);

void *modperl_config_srv_merge(apr_pool_t *p, void *basev, void *addv);

char *modperl_cmd_push_handlers(MpAV **handlers, const char *name,
                                apr_pool_t *p);

char **modperl_config_srv_argv_init(modperl_config_srv_t *scfg, int *argc);

#define MP_DECLARE_SRV_CMD(item) \
const char *modperl_cmd_##item(cmd_parms *parms, \
                               void *dummy, const char *arg)
MP_DECLARE_SRV_CMD(trace);
MP_DECLARE_SRV_CMD(switches);
MP_DECLARE_SRV_CMD(options);

#ifdef USE_ITHREADS
MP_DECLARE_SRV_CMD(interp_start);
MP_DECLARE_SRV_CMD(interp_max);
MP_DECLARE_SRV_CMD(interp_max_spare);
MP_DECLARE_SRV_CMD(interp_min_spare);
MP_DECLARE_SRV_CMD(interp_max_requests);
MP_DECLARE_SRV_CMD(interp_lifetime);

const char *modperl_interp_lifetime_desc(modperl_interp_lifetime_e lifetime);

#define modperl_interp_lifetime_undef(dcfg) \
(dcfg->interp_lifetime == MP_INTERP_LIFETIME_UNDEF)

#define modperl_interp_lifetime_handler(dcfg) \
(dcfg->interp_lifetime == MP_INTERP_LIFETIME_HANDLER)

#define modperl_interp_lifetime_subrequest(dcfg) \
(dcfg->interp_lifetime == MP_INTERP_LIFETIME_SUBREQUEST)

#define modperl_interp_lifetime_request(scfg) \
(scfg->interp_lifetime == MP_INTERP_LIFETIME_REQUEST)

#define modperl_interp_lifetime_connection(scfg) \
(scfg->interp_lifetime == MP_INTERP_LIFETIME_CONNECTION)

#endif

#define MP_SRV_CMD_TAKE1(name, item, desc) \
    AP_INIT_TAKE1( name, modperl_cmd_##item, NULL, \
      RSRC_CONF, desc )

#define MP_SRV_CMD_ITERATE(name, item, desc) \
   AP_INIT_ITERATE( name, modperl_cmd_##item, NULL, \
      RSRC_CONF, desc )

#define MP_DIR_CMD_TAKE1(name, item, desc) \
    AP_INIT_TAKE1( name, modperl_cmd_##item, NULL, \
      OR_ALL, desc )

#define modperl_config_req_init(r, rcfg) \
    if (!rcfg) { \
        rcfg = modperl_config_req_new(r); \
        ap_set_module_config(r->request_config, &perl_module, rcfg); \
    }

#define modperl_config_req_get(r) \
 (modperl_config_req_t *) \
          ap_get_module_config(r->request_config, &perl_module)

#define MP_dRCFG \
   modperl_config_req_t *rcfg = modperl_config_req_get(r)

#define modperl_config_dir_get(r) \
      (r ? (modperl_config_dir_t *) \
              ap_get_module_config(r->per_dir_config, &perl_module) : NULL)

#define MP_dDCFG \
   modperl_config_dir_t *dcfg = modperl_config_dir_get(r)

#define modperl_config_srv_get(s) \
 (modperl_config_srv_t *) \
          ap_get_module_config(s->module_config, &perl_module)

#define MP_dSCFG(s) \
   modperl_config_srv_t *scfg = modperl_config_srv_get(s)

#ifdef USE_ITHREADS
#   define MP_dSCFG_dTHX dTHXa(scfg->mip->parent->perl)
#else
#   define MP_dSCFG_dTHX dTHXa(scfg->perl)
#endif

#endif /* MODPERL_CONFIG_H */
