#include "mod_perl.h"

char *modperl_cmd_push_handlers(MpAV **handlers, const char *name,
                                apr_pool_t *p)
{
    modperl_handler_t *h = modperl_handler_new(p, name);

    if (!*handlers) {
        *handlers = apr_array_make(p, 1, sizeof(modperl_handler_t *));
        MP_TRACE_d(MP_FUNC, "created handler stack\n");
    }

    /* XXX parse_handler if Perl is running */

    *(modperl_handler_t **)apr_array_push(*handlers) = h;
    MP_TRACE_d(MP_FUNC, "pushed handler: %s\n", h->name);

    return NULL;
}

void *modperl_config_dir_create(apr_pool_t *p, char *dir)
{
    modperl_config_dir_t *dcfg = modperl_config_dir_new(p);

#ifdef USE_ITHREADS
    /* defaults to per-server lifetime */
    dcfg->interp_lifetime = MP_INTERP_LIFETIME_UNDEF;
#endif

    return dcfg;
}

#define merge_item(item) \
mrg->item = add->item ? add->item : base->item

void *modperl_config_dir_merge(apr_pool_t *p, void *basev, void *addv)
{
    modperl_config_dir_t
        *base = (modperl_config_dir_t *)basev,
        *add  = (modperl_config_dir_t *)addv,
        *mrg  = modperl_config_dir_new(p);

    MP_TRACE_d(MP_FUNC, "basev==0x%lx, addv==0x%lx\n", 
               (unsigned long)basev, (unsigned long)addv);

#ifdef USE_ITHREADS
    merge_item(interp_lifetime);
#endif

    { /* XXX: should do a proper merge of the arrays */
      /* XXX: and check if Perl*Handler is disabled */
        int i;
        for (i=0; i<MP_PER_DIR_NUM_HANDLERS; i++) {
            merge_item(handlers[i]);
        }
    }

    return mrg;
}

modperl_config_req_t *modperl_config_req_new(request_rec *r)
{
    modperl_config_req_t *rcfg = 
        (modperl_config_req_t *)apr_pcalloc(r->pool, sizeof(*rcfg));

    MP_TRACE_d(MP_FUNC, "0x%lx\n", (unsigned long)rcfg);

    return rcfg;
}

#define scfg_push_argv(arg) \
    *(const char **)apr_array_push(scfg->argv) = arg

modperl_config_srv_t *modperl_config_srv_new(apr_pool_t *p)
{
    modperl_config_srv_t *scfg = (modperl_config_srv_t *)
        apr_pcalloc(p, sizeof(*scfg));

    scfg->flags = modperl_options_new(p, MpSrvType);
    MpSrvENABLED_On(scfg); /* mod_perl enabled by default */
    MpSrvHOOKS_ALL_On(scfg); /* all hooks enabled by default */

    scfg->argv = apr_array_make(p, 2, sizeof(char *));

    scfg_push_argv((char *)ap_server_argv0);

#ifdef MP_CONNECTION_NUM_HANDLERS
    scfg->connection_cfg = (modperl_connection_config_t *)
        apr_pcalloc(p, sizeof(*scfg->connection_cfg));
#endif

#ifdef MP_FILES_NUM_HANDLERS
    scfg->files_cfg = (modperl_files_config_t *)
        apr_pcalloc(p, sizeof(*scfg->files_cfg));
#endif

#ifdef MP_PROCESS_NUM_HANDLERS
    scfg->process_cfg = (modperl_process_config_t *)
        apr_pcalloc(p, sizeof(*scfg->process_cfg));
#endif

    MP_TRACE_d(MP_FUNC, "0x%lx\n", (unsigned long)scfg);

    return scfg;
}

modperl_config_dir_t *modperl_config_dir_new(apr_pool_t *p)
{
    modperl_config_dir_t *dcfg = (modperl_config_dir_t *)
        apr_pcalloc(p, sizeof(modperl_config_dir_t));

    MP_TRACE_d(MP_FUNC, "0x%lx\n", (unsigned long)dcfg);

    return dcfg;
}

#ifdef MP_TRACE
static void dump_argv(modperl_config_srv_t *scfg)
{
    int i;
    char **argv = (char **)scfg->argv->elts;
    fprintf(stderr, "modperl_config_srv_argv_init =>\n");
    for (i=0; i<scfg->argv->nelts; i++) {
        fprintf(stderr, "   %d = %s\n", i, argv[i]);
    }
}
#endif

char **modperl_config_srv_argv_init(modperl_config_srv_t *scfg, int *argc)
{
    scfg_push_argv("-e;0");
    
    *argc = scfg->argv->nelts;

    MP_TRACE_g_do(dump_argv(scfg));

    return (char **)scfg->argv->elts;
}

void *modperl_config_srv_create(apr_pool_t *p, server_rec *s)
{
    modperl_config_srv_t *scfg = modperl_config_srv_new(p);

#ifdef USE_ITHREADS
    ap_mpm_query(AP_MPMQ_IS_THREADED, &scfg->threaded_mpm);

    scfg->interp_pool_cfg = 
        (modperl_tipool_config_t *)
        apr_pcalloc(p, sizeof(*scfg->interp_pool_cfg));

    scfg->interp_lifetime = MP_INTERP_LIFETIME_REQUEST;

    /* XXX: determine reasonable defaults */
    scfg->interp_pool_cfg->start = 3;
    scfg->interp_pool_cfg->max_spare = 3;
    scfg->interp_pool_cfg->min_spare = 3;
    scfg->interp_pool_cfg->max = 5;
    scfg->interp_pool_cfg->max_requests = 2000;
#endif /* USE_ITHREADS */

    return scfg;
}

/* XXX: this is not complete */
void *modperl_config_srv_merge(apr_pool_t *p, void *basev, void *addv)
{
    modperl_config_srv_t
        *base = (modperl_config_srv_t *)basev,
        *add  = (modperl_config_srv_t *)addv,
        *mrg  = modperl_config_srv_new(p);

    MP_TRACE_d(MP_FUNC, "basev==0x%lx, addv==0x%lx\n", 
               (unsigned long)basev, (unsigned long)addv);

#ifdef USE_ITHREADS
    merge_item(mip);
    merge_item(interp_pool_cfg);
    merge_item(interp_lifetime);
    merge_item(threaded_mpm);
#else
    merge_item(perl);
#endif

    merge_item(argv);
    merge_item(files_cfg);
    merge_item(process_cfg);
    merge_item(connection_cfg);

    { /* XXX: should do a proper merge of the arrays */
      /* XXX: and check if Perl*Handler is disabled */
        int i;
        for (i=0; i<MP_PER_SRV_NUM_HANDLERS; i++) {
            merge_item(handlers[i]);
        }
    }

    mrg->flags = modperl_options_merge(p, base->flags, add->flags);

    return mrg;
}

#define MP_CONFIG_BOOTSTRAP(parms) \
if (!scfg->mip) modperl_init(parms->server, parms->pool)

#define MP_SRV_CMD_TRACE \
    MP_TRACE_d(MP_FUNC, "%s %s\n", parms->cmd->name, arg)

#define MP_SRV_CMD_CHECK \
MP_SRV_CMD_TRACE; \
{ \
    const char *err = ap_check_cmd_context(parms, GLOBAL_ONLY); \
    if (err) return err; \
}

MP_DECLARE_SRV_CMD(trace)
{
    MP_SRV_CMD_CHECK;
    modperl_trace_level_set(arg);
    return NULL;
}

MP_DECLARE_SRV_CMD(switches)
{
    MP_dSCFG(parms->server);
    scfg_push_argv(arg);
    return NULL;
}

MP_DECLARE_SRV_CMD(options)
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

static const char *MP_interp_lifetime_desc[] = {
    "undef", "handler", "subrequest", "request", "connection",
};

const char *modperl_interp_lifetime_desc(modperl_interp_lifetime_e lifetime)
{
    return MP_interp_lifetime_desc[lifetime];
}

#define MP_INTERP_LIFETIME_USAGE "PerlInterpLifetime must be one of "

#define MP_INTERP_LIFETIME_DIR_OPTS \
"handler, subrequest or request"

#define MP_INTERP_LIFETIME_DIR_USAGE \
MP_INTERP_LIFETIME_USAGE MP_INTERP_LIFETIME_DIR_OPTS
 
#define MP_INTERP_LIFETIME_SRV_OPTS \
"connection, " MP_INTERP_LIFETIME_DIR_OPTS

#define MP_INTERP_LIFETIME_SRV_USAGE \
MP_INTERP_LIFETIME_USAGE MP_INTERP_LIFETIME_SRV_OPTS

MP_DECLARE_SRV_CMD(interp_lifetime)
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

#define MP_IMP_INTERP_POOL_CFG(xitem) \
const char *modperl_cmd_interp_##xitem(cmd_parms *parms, \
                                      void *dummy, const char *arg) \
{ \
    MP_dSCFG(parms->server); \
    int item = atoi(arg); \
    scfg->interp_pool_cfg->xitem = item; \
    MP_TRACE_d(MP_FUNC, "%s %d\n", parms->cmd->name, item); \
    return NULL; \
}

MP_IMP_INTERP_POOL_CFG(start);
MP_IMP_INTERP_POOL_CFG(max);
MP_IMP_INTERP_POOL_CFG(max_spare);
MP_IMP_INTERP_POOL_CFG(min_spare);
MP_IMP_INTERP_POOL_CFG(max_requests);

#endif /* USE_ITHREADS */
