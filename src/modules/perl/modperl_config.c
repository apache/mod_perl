#include "mod_perl.h"

char *modperl_cmd_push_handlers(MpAV **handlers, char *name, ap_pool_t *p)
{
    modperl_handler_t *h = modperl_handler_new(p, (void*)name,
                                               MP_HANDLER_TYPE_CHAR);
    if (!*handlers) {
        *handlers = ap_make_array(p, sizeof(modperl_handler_t), 1);
        MP_TRACE_d(MP_FUNC, "created handler stack\n");
    }

    /* XXX parse_handler if Perl is running */

    *(modperl_handler_t **)ap_push_array(*handlers) = h;
    MP_TRACE_d(MP_FUNC, "pushed handler: %s\n", h->name);

    return NULL;
}

void *modperl_create_dir_config(ap_pool_t *p, char *dir)
{
    modperl_dir_config_t *dcfg = modperl_dir_config_new(p);
    return dcfg;
}

void *modperl_merge_dir_config(ap_pool_t *p, void *basev, void *addv)
{
#if 0
    modperl_dir_config_t
        *base = (modperl_dir_config_t *)basev,
        *add  = (modperl_dir_config_t *)addv,
        *mrg  = modperl_dir_config_new(p);
#endif

    MP_TRACE_d(MP_FUNC, "basev==0x%lx, addv==0x%lx\n", 
               (unsigned long)basev, (unsigned long)addv);

    return addv;
}

modperl_request_config_t *modperl_request_config_new(request_rec *r)
{
    modperl_request_config_t *rcfg = 
        (modperl_request_config_t *)ap_pcalloc(r->pool, sizeof(*rcfg));

    MP_TRACE_d(MP_FUNC, "0x%lx\n", (unsigned long)rcfg);

    return rcfg;
}

#define scfg_push_argv(arg) \
    *(char **)ap_push_array(scfg->argv) = arg

modperl_srv_config_t *modperl_srv_config_new(ap_pool_t *p)
{
    modperl_srv_config_t *scfg = (modperl_srv_config_t *)
        ap_pcalloc(p, sizeof(*scfg));

    scfg->flags = modperl_options_new(p, MpSrvType);
    MpSrvENABLED_On(scfg); /* mod_perl enabled by default */
    MpSrvHOOKS_ALL_On(scfg); /* all hooks enabled by default */

    scfg->argv = ap_make_array(p, 2, sizeof(char *));

    scfg_push_argv((char *)ap_server_argv0);

#ifdef MP_CONNECTION_NUM_HANDLERS
    scfg->connection_cfg = (modperl_connection_config_t *)
        ap_pcalloc(p, sizeof(*scfg->connection_cfg));
#endif

#ifdef MP_FILES_NUM_HANDLERS
    scfg->files_cfg = (modperl_files_config_t *)
        ap_pcalloc(p, sizeof(*scfg->files_cfg));
#endif

#ifdef MP_PROCESS_NUM_HANDLERS
    scfg->process_cfg = (modperl_process_config_t *)
        ap_pcalloc(p, sizeof(*scfg->process_cfg));
#endif

    MP_TRACE_d(MP_FUNC, "0x%lx\n", (unsigned long)scfg);

    return scfg;
}

modperl_dir_config_t *modperl_dir_config_new(ap_pool_t *p)
{
    modperl_dir_config_t *dcfg = (modperl_dir_config_t *)
        ap_pcalloc(p, sizeof(modperl_dir_config_t));

    MP_TRACE_d(MP_FUNC, "0x%lx\n", (unsigned long)dcfg);

    return dcfg;
}

#ifdef MP_TRACE
static void dump_argv(modperl_srv_config_t *scfg)
{
    int i;
    char **argv = (char **)scfg->argv->elts;
    fprintf(stderr, "modperl_srv_config_argv_init =>\n");
    for (i=0; i<scfg->argv->nelts; i++) {
        fprintf(stderr, "   %d = %s\n", i, argv[i]);
    }
}
#endif

char **modperl_srv_config_argv_init(modperl_srv_config_t *scfg, int *argc)
{
    scfg_push_argv("-e;0");
    
    *argc = scfg->argv->nelts;

    MP_TRACE_g_do(dump_argv(scfg));

    return (char **)scfg->argv->elts;
}

void *modperl_create_srv_config(ap_pool_t *p, server_rec *s)
{
    modperl_srv_config_t *scfg = modperl_srv_config_new(p);

#ifdef USE_ITHREADS
    scfg->interp_pool_cfg = 
        (modperl_tipool_config_t *)
        ap_pcalloc(p, sizeof(*scfg->interp_pool_cfg));

    /* XXX: determine reasonable defaults */
    scfg->interp_pool_cfg->start = 3;
    scfg->interp_pool_cfg->max_spare = 3;
    scfg->interp_pool_cfg->min_spare = 3;
    scfg->interp_pool_cfg->max = 5;
    scfg->interp_pool_cfg->max_requests = 2000;
#endif /* USE_ITHREADS */

    return scfg;
}

#define merge_item(item) \
mrg->item = add->item ? add->item : base->item

/* XXX: this is not complete */
void *modperl_merge_srv_config(ap_pool_t *p, void *basev, void *addv)
{
    modperl_srv_config_t
        *base = (modperl_srv_config_t *)basev,
        *add  = (modperl_srv_config_t *)addv,
        *mrg  = modperl_srv_config_new(p);

    MP_TRACE_d(MP_FUNC, "basev==0x%lx, addv==0x%lx\n", 
               (unsigned long)basev, (unsigned long)addv);

#ifdef USE_ITHREADS
    merge_item(mip);
    merge_item(interp_pool_cfg);
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
    ap_pool_t *p = parms->pool;
    const char *error;

    MP_TRACE_d(MP_FUNC, "arg = %s\n", arg);
    error = modperl_options_set(p, scfg->flags, arg);

    if (error) {
        return error;
    }

    return NULL;
}

#ifdef USE_ITHREADS

#define MP_IMP_INTERP_POOL_CFG(item) \
const char *modperl_cmd_interp_##item(cmd_parms *parms, \
                                      void *dummy, char *arg) \
{ \
    MP_dSCFG(parms->server); \
    int item = atoi(arg); \
    scfg->interp_pool_cfg->##item = item; \
    MP_TRACE_d(MP_FUNC, "%s %d\n", parms->cmd->name, item); \
    return NULL; \
}

MP_IMP_INTERP_POOL_CFG(start);
MP_IMP_INTERP_POOL_CFG(max);
MP_IMP_INTERP_POOL_CFG(max_spare);
MP_IMP_INTERP_POOL_CFG(min_spare);
MP_IMP_INTERP_POOL_CFG(max_requests);

#endif /* USE_ITHREADS */
