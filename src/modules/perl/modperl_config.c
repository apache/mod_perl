#include "mod_perl.h"

void *modperl_create_dir_config(ap_pool_t *p, char *dir)
{
    return NULL;
}

void *modperl_merge_dir_config(ap_pool_t *p, void *base, void *add)
{
    return NULL;
}

modperl_srv_config_t *modperl_srv_config_new(ap_pool_t *p)
{
    return (modperl_srv_config_t *)
        ap_pcalloc(p, sizeof(modperl_srv_config_t));
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

MP_DECLARE_SRV_CMD(trace)
{
    modperl_trace_level_set(arg);
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
