#ifndef MODPERL_CMD_H
#define MODPERL_CMD_H

char *modperl_cmd_push_handlers(MpAV **handlers, const char *name,
                                apr_pool_t *p);


#define MP_CMD_SRV_DECLARE(item) \
const char *modperl_cmd_##item(cmd_parms *parms, \
                               void *dummy, const char *arg)
MP_CMD_SRV_DECLARE(trace);
MP_CMD_SRV_DECLARE(switches);
MP_CMD_SRV_DECLARE(options);

#ifdef USE_ITHREADS
MP_CMD_SRV_DECLARE(interp_start);
MP_CMD_SRV_DECLARE(interp_max);
MP_CMD_SRV_DECLARE(interp_max_spare);
MP_CMD_SRV_DECLARE(interp_min_spare);
MP_CMD_SRV_DECLARE(interp_max_requests);
MP_CMD_SRV_DECLARE(interp_lifetime);

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

#define MP_CMD_SRV_TAKE1(name, item, desc) \
    AP_INIT_TAKE1( name, modperl_cmd_##item, NULL, \
      RSRC_CONF, desc )

#define MP_CMD_SRV_ITERATE(name, item, desc) \
   AP_INIT_ITERATE( name, modperl_cmd_##item, NULL, \
      RSRC_CONF, desc )

#define MP_CMD_DIR_TAKE1(name, item, desc) \
    AP_INIT_TAKE1( name, modperl_cmd_##item, NULL, \
      OR_ALL, desc )

#endif /* MODPERL_CMD_H */
