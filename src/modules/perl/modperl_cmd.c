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
    MP_TRACE_d(MP_FUNC, "arg = %s\n", arg);
    modperl_config_srv_argv_push(arg);
    return NULL;
}

MP_CMD_SRV_DECLARE(modules)
{
    MP_dSCFG(parms->server);
    *(const char **)apr_array_push(scfg->PerlModule) = arg;
    MP_TRACE_d(MP_FUNC, "arg = %s\n", arg);
    return NULL;
}

MP_CMD_SRV_DECLARE(requires)
{
    MP_dSCFG(parms->server);
    *(const char **)apr_array_push(scfg->PerlRequire) = arg;
    MP_TRACE_d(MP_FUNC, "arg = %s\n", arg);
    return NULL;
}

MP_CMD_SRV_DECLARE2(set_var)
{
    MP_dSCFG(parms->server);
    modperl_config_dir_t *dcfg = (modperl_config_dir_t *)mconfig;
 
    if (parms->path) {
        apr_table_set(dcfg->SetVar, arg1, arg2);
        MP_TRACE_d(MP_FUNC, "DIR: arg1 = %s, arg2 = %s\n", arg1, arg2);
    }
    else {
        apr_table_set(scfg->SetVar, arg1, arg2);
        MP_TRACE_d(MP_FUNC, "SRV: arg1 = %s, arg2 = %s\n", arg1, arg2);
    }
    return NULL;
}

MP_CMD_SRV_DECLARE2(add_var)
{
    MP_dSCFG(parms->server);
    modperl_config_dir_t *dcfg = (modperl_config_dir_t *)mconfig;
 
    if (parms->path) {
        apr_table_add(dcfg->SetVar, arg1, arg2);
        MP_TRACE_d(MP_FUNC, "DIR: arg1 = %s, arg2 = %s\n", arg1, arg2);
    }
    else {
        apr_table_add(scfg->SetVar, arg1, arg2);
        MP_TRACE_d(MP_FUNC, "SRV: arg1 = %s, arg2 = %s\n", arg1, arg2);
    }
    return NULL;
}

MP_CMD_SRV_DECLARE2(set_env)
{
    MP_dSCFG(parms->server);
    modperl_config_dir_t *dcfg = (modperl_config_dir_t *)mconfig;
 
    MP_TRACE_d(MP_FUNC, "arg1 = %s, arg2 = %s\n", arg1, arg2);

    if (!parms->path) {
        /* will be propagated to environ */
        apr_table_setn(scfg->SetEnv, arg1, arg2);
    }

    apr_table_setn(dcfg->SetEnv, arg1, arg2);

    return NULL;
}

MP_CMD_SRV_DECLARE(pass_env)
{
    MP_dSCFG(parms->server);
    char *val = getenv(arg);
 
    if (val) {
        apr_table_setn(scfg->PassEnv, arg, apr_pstrdup(parms->pool, val));
        MP_TRACE_d(MP_FUNC, "arg = %s, val = %s\n", arg, val);
    }
    else {
        MP_TRACE_d(MP_FUNC, "arg = %s: not found via getenv()\n", arg);
    }

    return NULL;
}

MP_CMD_SRV_DECLARE(options)
{
    MP_dSCFG(parms->server);
    modperl_config_dir_t *dcfg = (modperl_config_dir_t *)mconfig;
    int is_per_dir = parms->path ? 1 : 0;
    modperl_options_t *opts = is_per_dir ? dcfg->flags : scfg->flags;
    apr_pool_t *p = parms->pool;
    const char *error;

    MP_TRACE_d(MP_FUNC, "arg = %s\n", arg);
    if ((error = modperl_options_set(p, opts, arg)) && !is_per_dir) {
        /* maybe a per-directory option outside of a container */
        if (modperl_options_set(p, dcfg->flags, arg) == NULL) {
            error = NULL;
        }
    }

    if (error) {
        return error;
    }

    return NULL;
}

MP_CMD_SRV_DECLARE(init_handlers)
{
    if (parms->path) {
        return modperl_cmd_header_parser_handlers(parms, mconfig, arg);
    }

    return modperl_cmd_post_read_request_handlers(parms, mconfig, arg);
}

MP_CMD_SRV_DECLARE(perl)
{
    return "<Perl> sections not yet implemented in modperl-2.0";
}

#ifdef MP_COMPAT_1X

MP_CMD_SRV_DECLARE_FLAG(taint_check)
{
    if (flag_on) {
        return modperl_cmd_switches(parms, mconfig, "-T");
    }

    return NULL;
}

MP_CMD_SRV_DECLARE_FLAG(warn)
{
    if (flag_on) {
        return modperl_cmd_switches(parms, mconfig, "-w");
    }

    return NULL;
}

MP_CMD_SRV_DECLARE_FLAG(send_header)
{
    char *arg = flag_on ? "+ParseHeaders" : "-ParseHeaders";
    return modperl_cmd_options(parms, mconfig, arg);
}

MP_CMD_SRV_DECLARE_FLAG(setup_env)
{
    char *arg = flag_on ? "+SetupEnv" : "-SetupEnv";
    return modperl_cmd_options(parms, mconfig, arg);
}

#endif /* MP_COMPAT_1X */

#ifdef USE_ITHREADS

#define MP_INTERP_SCOPE_USAGE "PerlInterpScope must be one of "

#define MP_INTERP_SCOPE_DIR_OPTS \
"handler, subrequest or request"

#define MP_INTERP_SCOPE_DIR_USAGE \
MP_INTERP_SCOPE_USAGE MP_INTERP_SCOPE_DIR_OPTS
 
#define MP_INTERP_SCOPE_SRV_OPTS \
"connection, " MP_INTERP_SCOPE_DIR_OPTS

#define MP_INTERP_SCOPE_SRV_USAGE \
MP_INTERP_SCOPE_USAGE MP_INTERP_SCOPE_SRV_OPTS

MP_CMD_SRV_DECLARE(interp_scope)
{
    modperl_interp_scope_e *scope;
    modperl_config_dir_t *dcfg = (modperl_config_dir_t *)mconfig;
    MP_dSCFG(parms->server);
    int is_per_dir = parms->path ? 1 : 0;

    scope = is_per_dir ? &dcfg->interp_scope : &scfg->interp_scope;

    switch (toLOWER(*arg)) {
      case 'h':
        if (strcaseEQ(arg, "handler")) {
            *scope = MP_INTERP_SCOPE_HANDLER;
            break;
        }
      case 's':
        if (strcaseEQ(arg, "subrequest")) {
            *scope = MP_INTERP_SCOPE_SUBREQUEST;
            break;
        }
      case 'r':
        if (strcaseEQ(arg, "request")) {
            *scope = MP_INTERP_SCOPE_REQUEST;
            break;
        }
      case 'c':
        if (!is_per_dir && strcaseEQ(arg, "connection")) {
            *scope = MP_INTERP_SCOPE_CONNECTION;
            break;
        }
      default:
        return is_per_dir ?
             MP_INTERP_SCOPE_DIR_USAGE : MP_INTERP_SCOPE_SRV_USAGE;
    };

    return NULL;
}

#define MP_CMD_INTERP_POOL_IMP(xitem) \
const char *modperl_cmd_interp_##xitem(cmd_parms *parms, \
                                      void *mconfig, const char *arg) \
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
