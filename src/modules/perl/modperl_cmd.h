#ifndef MODPERL_CMD_H
#define MODPERL_CMD_H

char *modperl_cmd_push_handlers(MpAV **handlers, const char *name,
                                apr_pool_t *p);


#define MP_CMD_SRV_DECLARE(item) \
const char *modperl_cmd_##item(cmd_parms *parms, \
                               void *dummy, const char *arg)
#define MP_CMD_SRV_DECLARE2(item) \
const char *modperl_cmd_##item(cmd_parms *parms, \
                               void *dummy, const char *arg1, const char *arg2)
MP_CMD_SRV_DECLARE(trace);
MP_CMD_SRV_DECLARE(switches);
MP_CMD_SRV_DECLARE(modules);
MP_CMD_SRV_DECLARE(requires);
MP_CMD_SRV_DECLARE(options);

#ifdef USE_ITHREADS
MP_CMD_SRV_DECLARE(interp_start);
MP_CMD_SRV_DECLARE(interp_max);
MP_CMD_SRV_DECLARE(interp_max_spare);
MP_CMD_SRV_DECLARE(interp_min_spare);
MP_CMD_SRV_DECLARE(interp_max_requests);
MP_CMD_SRV_DECLARE(interp_scope);

#define modperl_interp_scope_undef(dcfg) \
(dcfg->interp_scope == MP_INTERP_SCOPE_UNDEF)

#define modperl_interp_scope_handler(dcfg) \
(dcfg->interp_scope == MP_INTERP_SCOPE_HANDLER)

#define modperl_interp_scope_subrequest(dcfg) \
(dcfg->interp_scope == MP_INTERP_SCOPE_SUBREQUEST)

#define modperl_interp_scope_request(scfg) \
(scfg->interp_scope == MP_INTERP_SCOPE_REQUEST)

#define modperl_interp_scope_connection(scfg) \
(scfg->interp_scope == MP_INTERP_SCOPE_CONNECTION)

#endif

#define MP_CMD_SRV_TAKE1(name, item, desc) \
    AP_INIT_TAKE1( name, modperl_cmd_##item, NULL, \
      RSRC_CONF, desc )

#define MP_CMD_SRV_TAKE2(name, item, desc) \
    AP_INIT_TAKE2( name, modperl_cmd_##item, NULL, \
      RSRC_CONF, desc )

#define MP_CMD_SRV_ITERATE(name, item, desc) \
   AP_INIT_ITERATE( name, modperl_cmd_##item, NULL, \
      RSRC_CONF, desc )

#define MP_CMD_DIR_TAKE1(name, item, desc) \
    AP_INIT_TAKE1( name, modperl_cmd_##item, NULL, \
      OR_ALL, desc )

#define MP_CMD_DIR_TAKE2(name, item, desc) \
    AP_INIT_TAKE2( name, modperl_cmd_##item, NULL, \
      OR_ALL, desc )

#define MP_CMD_DIR_ITERATE(name, item, desc) \
    AP_INIT_ITERATE( name, modperl_cmd_##item, NULL, \
      OR_ALL, desc )

#endif /* MODPERL_CMD_H */
