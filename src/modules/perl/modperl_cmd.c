#include "mod_perl.h"

char *modperl_cmd_push_handlers(MpAV **handlers, const char *name,
                                apr_pool_t *p)
{
    modperl_handler_t *h = modperl_handler_new(p, name);

    if (!*handlers) {
        *handlers = modperl_handler_array_new(p);
        MP_TRACE_d(MP_FUNC, "created handler stack\n");
    }

    /* XXX parse_handler if Perl is running */

    modperl_handler_array_push(*handlers, h);
    MP_TRACE_d(MP_FUNC, "pushed handler: %s\n", h->name);

    return NULL;
}


#define MP_CMD_SRV_TRACE \
    MP_TRACE_d(MP_FUNC, "%s %s\n", parms->cmd->name, arg)

#define MP_CMD_SRV_CHECK \
MP_CMD_SRV_TRACE; \
{ \
    const char *err = ap_check_cmd_context(parms, GLOBAL_ONLY); \
    if (err) return err; \
}

MP_CMD_SRV_DECLARE(trace)
{
    MP_CMD_SRV_CHECK;
    modperl_trace_level_set(arg);
    return NULL;
}

MP_CMD_SRV_DECLARE(switches)
{
    MP_dSCFG(parms->server);
    modperl_config_srv_argv_push(arg);
    return NULL;
}

MP_CMD_SRV_DECLARE(options)
{
    MP_dSCFG(parms->server);
    apr_pool_t *p = parms->pool;
    const char *error;

    MP_TRACE_d(MP_FUNC, "arg = %s\n", arg);
    error = modperl_options_set(p, scfg->flags, arg);

    if (error) {
        return error;
    }

    return NULL;
}

#ifdef USE_ITHREADS

#define MP_INTERP_LIFETIME_USAGE "PerlInterpLifetime must be one of "

#define MP_INTERP_LIFETIME_DIR_OPTS \
"handler, subrequest or request"

#define MP_INTERP_LIFETIME_DIR_USAGE \
MP_INTERP_LIFETIME_USAGE MP_INTERP_LIFETIME_DIR_OPTS
 
#define MP_INTERP_LIFETIME_SRV_OPTS \
"connection, " MP_INTERP_LIFETIME_DIR_OPTS

#define MP_INTERP_LIFETIME_SRV_USAGE \
MP_INTERP_LIFETIME_USAGE MP_INTERP_LIFETIME_SRV_OPTS

MP_CMD_SRV_DECLARE(interp_lifetime)
{
    modperl_interp_lifetime_e *lifetime;
    modperl_config_dir_t *dcfg = (modperl_config_dir_t *)dummy;
    MP_dSCFG(parms->server);
    int is_per_dir = parms->path ? 1 : 0;

    lifetime = is_per_dir ? &dcfg->interp_lifetime : &scfg->interp_lifetime;

    switch (toLOWER(*arg)) {
      case 'h':
        if (strcaseEQ(arg, "handler")) {
            *lifetime = MP_INTERP_LIFETIME_HANDLER;
            break;
        }
      case 's':
        if (strcaseEQ(arg, "subrequest")) {
            *lifetime = MP_INTERP_LIFETIME_SUBREQUEST;
            break;
        }
      case 'r':
        if (strcaseEQ(arg, "request")) {
            *lifetime = MP_INTERP_LIFETIME_REQUEST;
            break;
        }
      case 'c':
        if (!is_per_dir && strcaseEQ(arg, "connection")) {
            *lifetime = MP_INTERP_LIFETIME_CONNECTION;
            break;
        }
      default:
        return is_per_dir ?
            MP_INTERP_LIFETIME_DIR_USAGE : MP_INTERP_LIFETIME_SRV_USAGE;
    };

    return NULL;
}

#define MP_CMD_INTERP_POOL_IMP(xitem) \
const char *modperl_cmd_interp_##xitem(cmd_parms *parms, \
                                      void *dummy, const char *arg) \
{ \
    MP_dSCFG(parms->server); \
    int item = atoi(arg); \
    scfg->interp_pool_cfg->xitem = item; \
    MP_TRACE_d(MP_FUNC, "%s %d\n", parms->cmd->name, item); \
    return NULL; \
}

MP_CMD_INTERP_POOL_IMP(start);
MP_CMD_INTERP_POOL_IMP(max);
MP_CMD_INTERP_POOL_IMP(max_spare);
MP_CMD_INTERP_POOL_IMP(min_spare);
MP_CMD_INTERP_POOL_IMP(max_requests);

#endif /* USE_ITHREADS */
