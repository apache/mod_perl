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
    return NULL;
}

void *modperl_merge_dir_config(ap_pool_t *p, void *base, void *add)
{
    return NULL;
}

#define scfg_push_argv(arg) \
    *(char **)ap_push_array(scfg->argv) = arg

modperl_srv_config_t *modperl_srv_config_new(ap_pool_t *p)
{
    modperl_srv_config_t *scfg = (modperl_srv_config_t *)
        ap_pcalloc(p, sizeof(modperl_srv_config_t));

    scfg->argv = ap_make_array(p, 2, sizeof(char *));

    scfg_push_argv((char *)ap_server_argv0);

    return scfg;
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
        (modperl_interp_pool_config_t *)
        ap_pcalloc(p, sizeof(*scfg->interp_pool_cfg));

    /* XXX: determine reasonable defaults */
    scfg->interp_pool_cfg->start = 3;
    scfg->interp_pool_cfg->max_spare = 3;
    scfg->interp_pool_cfg->min_spare = 3;
    scfg->interp_pool_cfg->max = 5;

#endif /* USE_ITHREADS */

    return scfg;
}

#define merge_item(item) \
mrg->item = add->item ? add->item : base->item

void *modperl_merge_srv_config(ap_pool_t *p, void *basev, void *addv)
{
#if 0
    modperl_srv_config_t
        *base = (modperl_srv_config_t *)basev,
        *add  = (modperl_srv_config_t *)addv,
        *mrg  = modperl_srv_config_new(p);

    return mrg;
#else
    return basev;
#endif
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
    MP_SRV_CMD_CHECK;
    scfg_push_argv(arg);
    return NULL;
}

#ifdef USE_ITHREADS

#define MP_IMP_INTERP_POOL_CFG(item) \
const char *modperl_cmd_interp_##item(cmd_parms *parms, \
                                      void *dummy, char *arg) \
{ \
    MP_dSCFG(parms->server); \
    int item = atoi(arg); \
    const char *err = ap_check_cmd_context(parms, GLOBAL_ONLY); \
    if (err) return err; \
    scfg->interp_pool_cfg->##item = item; \
    MP_TRACE_d(MP_FUNC, "%s %d\n", parms->cmd->name, item); \
    return NULL; \
}

MP_IMP_INTERP_POOL_CFG(start);
MP_IMP_INTERP_POOL_CFG(max);
MP_IMP_INTERP_POOL_CFG(max_spare);
MP_IMP_INTERP_POOL_CFG(min_spare);

#endif /* USE_ITHREADS */
