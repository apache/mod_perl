char *modperl_cmd_push_handlers(MpAV *handlers, char *name, ap_context_t *ctx);

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
