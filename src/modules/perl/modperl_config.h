#ifndef MODPERL_CONFIG_H
#define MODPERL_CONFIG_H

char *modperl_cmd_push_handlers(MpAV *handlers, char *name, ap_pool_t *p);

#define MP_dRCFG \
   modperl_request_config_t *rcfg = \
      (modperl_request_config_t *) \
          ap_get_module_config(r->request_config, &perl_module)

#define MP_dDCFG \
   modperl_dir_config_t *dcfg = \
      (modperl_dir_config_t *) \
          ap_get_module_config(r->per_dir_config, &perl_module)   

#define MP_dSCFG(s) \
   modperl_srv_config_t *scfg = \
      (modperl_srv_config_t *) \
          ap_get_module_config(s->module_config, &perl_module)

#endif /* MODPERL_CONFIG_H */
