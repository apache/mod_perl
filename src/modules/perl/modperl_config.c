#include "mod_perl.h"

void *modperl_config_dir_create(apr_pool_t *p, char *dir)
{
    modperl_config_dir_t *dcfg = modperl_config_dir_new(p);

    dcfg->location = dir;
    
#ifdef USE_ITHREADS
    /* defaults to per-server scope */
    dcfg->interp_scope = MP_INTERP_SCOPE_UNDEF;
#endif

    return dcfg;
}

#define merge_item(item) \
    mrg->item = add->item ? add->item : base->item

/* take the 'base' values, and override with 'add' values if any */
static apr_table_t *modperl_table_overlap(apr_pool_t *p,
                                          apr_table_t *base,
                                          apr_table_t *add)
{
    int i;
    const apr_array_header_t *arr = apr_table_elts(base);
    apr_table_entry_t *entries  = (apr_table_entry_t *)arr->elts;
    apr_table_t *merge = apr_table_copy(p, add);

    for (i = 0; i < arr->nelts; i++) {
        if (apr_table_get(add, entries[i].key)) {
            continue;
        }
        else {
            apr_table_addn(merge, entries[i].key, entries[i].val);
        }
    }

    return merge;
}

#define merge_table_overlap_item(item) \
    mrg->item = modperl_table_overlap(p, base->item, add->item)

#define merge_handlers(merge_flag, array) \
    if (merge_flag(mrg)) { \
        mrg->array = modperl_handler_array_merge(p, \
                                                 base->array, \
                                                 add->array); \
    } \
    else { \
        merge_item(array); \
    }

void *modperl_config_dir_merge(apr_pool_t *p, void *basev, void *addv)
{
    int i;
    modperl_config_dir_t
        *base = (modperl_config_dir_t *)basev,
        *add  = (modperl_config_dir_t *)addv,
        *mrg  = modperl_config_dir_new(p);

    MP_TRACE_d(MP_FUNC, "basev==0x%lx, addv==0x%lx\n", 
               (unsigned long)basev, (unsigned long)addv);

#ifdef USE_ITHREADS
    merge_item(interp_scope);
#endif

    mrg->flags = modperl_options_merge(p, base->flags, add->flags);

    merge_item(location);
    
    merge_table_overlap_item(vars);
    
    merge_table_overlap_item(SetEnv);

    /* XXX: check if Perl*Handler is disabled */
    for (i=0; i < MP_HANDLER_NUM_PER_DIR; i++) {
        merge_handlers(MpDirMERGE_HANDLERS, handlers_per_dir[i]);
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

modperl_config_srv_t *modperl_config_srv_new(apr_pool_t *p)
{
    modperl_config_srv_t *scfg = (modperl_config_srv_t *)
        apr_pcalloc(p, sizeof(*scfg));

    scfg->flags = modperl_options_new(p, MpSrvType);
    MpSrvENABLE_On(scfg); /* mod_perl enabled by default */
    MpSrvHOOKS_ALL_On(scfg); /* all hooks enabled by default */

    scfg->PerlModule  = apr_array_make(p, 2, sizeof(char *));
    scfg->PerlRequire = apr_array_make(p, 2, sizeof(char *));

    scfg->argv = apr_array_make(p, 2, sizeof(char *));

    scfg->vars = apr_table_make(p, 2);

    scfg->PassEnv = apr_table_make(p, 2);
    scfg->SetEnv = apr_table_make(p, 2);
    
#ifdef MP_USE_GTOP
    scfg->gtop = modperl_gtop_new(p);
#endif        
    
    modperl_config_srv_argv_push((char *)ap_server_argv0);

    MP_TRACE_d(MP_FUNC, "new scfg: 0x%lx\n", (unsigned long)scfg);

    return scfg;
}

modperl_config_dir_t *modperl_config_dir_new(apr_pool_t *p)
{
    modperl_config_dir_t *dcfg = (modperl_config_dir_t *)
        apr_pcalloc(p, sizeof(modperl_config_dir_t));

    dcfg->flags = modperl_options_new(p, MpDirType);

    dcfg->vars = apr_table_make(p, 2);

    dcfg->SetEnv = apr_table_make(p, 2);
    
    MP_TRACE_d(MP_FUNC, "new dcfg: 0x%lx\n", (unsigned long)dcfg);

    return dcfg;
}

#ifdef MP_TRACE
static void dump_argv(modperl_config_srv_t *scfg)
{
    int i;
    char **argv = (char **)scfg->argv->elts;
    modperl_trace(NULL, "modperl_config_srv_argv_init =>");
    for (i=0; i<scfg->argv->nelts; i++) {
        modperl_trace(NULL, "   %d = %s", i, argv[i]);
    }
}
#endif

char **modperl_config_srv_argv_init(modperl_config_srv_t *scfg, int *argc)
{
    modperl_config_srv_argv_push("-e;0");
    
    *argc = scfg->argv->nelts;

    MP_TRACE_g_do(dump_argv(scfg));

    return (char **)scfg->argv->elts;
}

void *modperl_config_srv_create(apr_pool_t *p, server_rec *s)
{
    modperl_config_srv_t *scfg = modperl_config_srv_new(p);

    ap_mpm_query(AP_MPMQ_IS_THREADED, &scfg->threaded_mpm);

    if (!s->is_virtual) {

        /* give a chance to MOD_PERL_TRACE env var to set
         * PerlTrace. This place is the earliest point in mod_perl
         * configuration parsing, when we have the server object
         */
        modperl_trace_level_set(s, NULL);

        /* Must store the global server record as early as possible,
         * because if mod_perl happens to be started from within a
         * vhost (e.g., PerlLoadModule) the base server record won't
         * be available to vhost and things will blow up
         */
        modperl_init_globals(s, p);
    }
    
    MP_TRACE_d(MP_FUNC, "p=0x%lx, s=0x%lx, virtual=%d\n",
               p, s, s->is_virtual);

#ifdef USE_ITHREADS

    scfg->interp_pool_cfg = 
        (modperl_tipool_config_t *)
        apr_pcalloc(p, sizeof(*scfg->interp_pool_cfg));

    scfg->interp_scope = MP_INTERP_SCOPE_REQUEST;

    /* XXX: determine reasonable defaults */
    scfg->interp_pool_cfg->start = 3;
    scfg->interp_pool_cfg->max_spare = 3;
    scfg->interp_pool_cfg->min_spare = 3;
    scfg->interp_pool_cfg->max = 5;
    scfg->interp_pool_cfg->max_requests = 2000;
#endif /* USE_ITHREADS */

    scfg->server = s;

    return scfg;
}

/* XXX: this is not complete */
void *modperl_config_srv_merge(apr_pool_t *p, void *basev, void *addv)
{
    int i;
    modperl_config_srv_t
        *base = (modperl_config_srv_t *)basev,
        *add  = (modperl_config_srv_t *)addv,
        *mrg  = modperl_config_srv_new(p);

    MP_TRACE_d(MP_FUNC, "basev==0x%lx, addv==0x%lx\n", 
               (unsigned long)basev, (unsigned long)addv);

    merge_item(modules);
    merge_item(PerlModule);
    merge_item(PerlRequire);

    merge_table_overlap_item(vars);

    merge_table_overlap_item(SetEnv);
    merge_table_overlap_item(PassEnv);
 
    merge_item(threaded_mpm);
    merge_item(server);

#ifdef USE_ITHREADS
    merge_item(interp_pool_cfg);
    merge_item(interp_scope);
#else
    merge_item(perl);
#endif

    if (add->argv->nelts == 2 &&
        strEQ(((char **)add->argv->elts)[1], "+inherit"))
    {
        /* only inherit base PerlSwitches if explicitly told to */
        mrg->argv = base->argv;
    }
    else {
        mrg->argv = add->argv;
    }

    mrg->flags = modperl_options_merge(p, base->flags, add->flags);

    /* XXX: check if Perl*Handler is disabled */
    for (i=0; i < MP_HANDLER_NUM_PER_SRV; i++) {
        merge_handlers(MpSrvMERGE_HANDLERS, handlers_per_srv[i]);
    }
    for (i=0; i < MP_HANDLER_NUM_FILES; i++) {
        merge_handlers(MpSrvMERGE_HANDLERS, handlers_files[i]);
    }
    for (i=0; i < MP_HANDLER_NUM_PROCESS; i++) {
        merge_handlers(MpSrvMERGE_HANDLERS, handlers_process[i]);
    }
    for (i=0; i < MP_HANDLER_NUM_PRE_CONNECTION; i++) {
        merge_handlers(MpSrvMERGE_HANDLERS, handlers_pre_connection[i]);
    }
    for (i=0; i < MP_HANDLER_NUM_CONNECTION; i++) {
        merge_handlers(MpSrvMERGE_HANDLERS, handlers_connection[i]);
    }

    if (modperl_is_running()) {
        if (modperl_init_vhost(mrg->server, p, NULL) != OK) {
            exit(1); /*XXX*/
        }
    }

#ifdef USE_ITHREADS
    merge_item(mip);
#endif

    return mrg;
}

/* any per-request cleanup goes here */

apr_status_t modperl_config_request_cleanup(pTHX_ request_rec *r)
{
    apr_status_t retval;
    MP_dRCFG;

    retval = modperl_callback_per_dir(MP_CLEANUP_HANDLER, r, MP_HOOK_RUN_ALL);

    if (rcfg->pnotes) {
        SvREFCNT_dec(rcfg->pnotes);
        rcfg->pnotes = Nullhv;
    }

    /* undo changes to %ENV caused by +SetupEnv, perl-script, or
     * $r->subprocess_env, so the values won't persist  */
    if (MpReqSETUP_ENV(rcfg)) {
        modperl_env_request_unpopulate(aTHX_ r);
    }

    return retval;
}

apr_status_t modperl_config_req_cleanup(void *data)
{
    request_rec *r = (request_rec *)data;
    MP_dTHX;

    return modperl_config_request_cleanup(aTHX_ r);
}

void *modperl_get_perl_module_config(ap_conf_vector_t *cv)
{
    return ap_get_module_config(cv, &perl_module);
}

void modperl_set_perl_module_config(ap_conf_vector_t *cv, void *cfg)
{
    ap_set_module_config(cv, &perl_module, cfg);
}

int modperl_config_apply_PerlModule(server_rec *s,
                                    modperl_config_srv_t *scfg,
                                    PerlInterpreter *perl, apr_pool_t *p)
{
    char **entries;
    int i;
    dTHXa(perl);

    entries = (char **)scfg->PerlModule->elts;
    for (i = 0; i < scfg->PerlModule->nelts; i++){
        if (modperl_require_module(aTHX_ entries[i], TRUE)){
            MP_TRACE_d(MP_FUNC, "loaded Perl module %s for server %s\n",
                       entries[i], modperl_server_desc(s,p));
        }
        else {
            ap_log_error(APLOG_MARK, APLOG_ERR, 0, s,
                         "Can't load Perl module %s for server %s, exiting...\n",
                         entries[i], modperl_server_desc(s,p));
            return FALSE;
        }
    }

    return TRUE;
}

int modperl_config_apply_PerlRequire(server_rec *s,
                                     modperl_config_srv_t *scfg,
                                     PerlInterpreter *perl, apr_pool_t *p)
{
    char **entries;
    int i;
    dTHXa(perl);

    entries = (char **)scfg->PerlRequire->elts;
    for (i = 0; i < scfg->PerlRequire->nelts; i++){
        if (modperl_require_file(aTHX_ entries[i], TRUE)){
            MP_TRACE_d(MP_FUNC, "loaded Perl file: %s for server %s\n",
                       entries[i], modperl_server_desc(s,p));
        }
        else {
            ap_log_error(APLOG_MARK, APLOG_ERR, 0, s,
                         "Can't load Perl file: %s for server %s, exiting...\n",
                         entries[i], modperl_server_desc(s,p));
            return FALSE;
        }
    }

    return TRUE;
}

typedef struct {
    AV *av;
    I32 ix;
    PerlInterpreter *perl;
} svav_param_t;

static void *svav_getstr(void *buf, size_t bufsiz, void *param)
{
    svav_param_t *svav_param = (svav_param_t *)param;
    dTHXa(svav_param->perl);
    AV *av = svav_param->av;
    SV *sv;
    STRLEN n_a;

    if (svav_param->ix > AvFILL(av)) {
        return NULL;
    }

    sv = AvARRAY(av)[svav_param->ix++];
    SvPV_force(sv, n_a);

    apr_cpystrn(buf, SvPVX(sv), bufsiz);

    return buf;
}

const char *modperl_config_insert(pTHX_ server_rec *s,
                                  apr_pool_t *p,
                                  apr_pool_t *ptmp,
                                  int override,
                                  char *path,
                                  ap_conf_vector_t *conf,
                                  SV *lines)
{
    const char *errmsg;
    cmd_parms parms;
    svav_param_t svav_parms;
    ap_directive_t *conftree = NULL;

    memset(&parms, '\0', sizeof(parms));

    parms.limited = -1;
    parms.server = s;
    parms.override = override;
    parms.path = path;
    parms.pool = p;

    if (ptmp) {
        parms.temp_pool = ptmp;
    }
    else {
        apr_pool_create(&parms.temp_pool, p);
    }

    if (!(SvROK(lines) && (SvTYPE(SvRV(lines)) == SVt_PVAV))) {
        return "not an array reference";
    }

    svav_parms.av = (AV*)SvRV(lines);
    svav_parms.ix = 0;
#ifdef USE_ITHREADS
    svav_parms.perl = aTHX;
#endif

    parms.config_file = ap_pcfg_open_custom(p, "mod_perl",
                                            &svav_parms, NULL,
                                            svav_getstr, NULL);

    errmsg = ap_build_config(&parms, p, parms.temp_pool, &conftree);

    if (!errmsg) {
        errmsg = ap_walk_config(conftree, &parms, conf);
    }

    ap_cfg_closefile(parms.config_file);

    if (ptmp != parms.temp_pool) {
        apr_pool_destroy(parms.temp_pool);
    }

    return errmsg;
}

const char *modperl_config_insert_server(pTHX_ server_rec *s, SV *lines)
{
    int override = (RSRC_CONF | OR_ALL) & ~(OR_AUTHCFG | OR_LIMIT);
    apr_pool_t *p = s->process->pconf;

    return modperl_config_insert(aTHX_ s, p, NULL, override, NULL,
                                 s->lookup_defaults, lines);
}

const char *modperl_config_insert_request(pTHX_
                                          request_rec *r,
                                          SV *lines,
                                          char *path,
                                          int override)
{
    const char *errmsg;
    ap_conf_vector_t *dconf = ap_create_per_dir_config(r->pool);

    errmsg = modperl_config_insert(aTHX_
                                   r->server, r->pool, r->pool,
                                   override, path,
                                   dconf, lines);

    if (errmsg) {
        return errmsg;
    }

    r->per_dir_config = 
        ap_merge_per_dir_configs(r->pool,
                                 r->per_dir_config,
                                 dconf);

    return NULL;
}
