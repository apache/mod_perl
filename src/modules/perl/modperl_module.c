#include "mod_perl.h"

typedef struct {
    server_rec *server;
    const char *name;
    int namelen;
} modperl_module_cfg_t;

typedef struct {
    module *modp;
    const char *cmd_data;
    const char *func_name;
} modperl_module_cmd_data_t;

static modperl_module_cfg_t *modperl_module_cfg_new(apr_pool_t *p)
{
    modperl_module_cfg_t *cfg =
        (modperl_module_cfg_t *)apr_pcalloc(p, sizeof(*cfg));

    return cfg;
}

static modperl_module_cmd_data_t *modperl_module_cmd_data_new(apr_pool_t *p)
{
    modperl_module_cmd_data_t *cmd_data =
        (modperl_module_cmd_data_t *)apr_pcalloc(p, sizeof(*cmd_data));

    return cmd_data;
}

static void *modperl_module_config_dir_create(apr_pool_t *p, char *dir)
{
    return modperl_module_cfg_new(p);
}

static void *modperl_module_config_srv_create(apr_pool_t *p, server_rec *s)
{
    return modperl_module_cfg_new(p);
}

static SV **modperl_module_config_hash_get(pTHX_ int create)
{
    SV **svp;

    /* XXX: could make this lookup faster */
    svp = hv_fetch(PL_modglobal,
                   "ModPerl::Module::ConfigTable",
                   MP_SSTRLEN("ModPerl::Module::ConfigTable"),
                   create);

    return svp;
}

void modperl_module_config_table_set(pTHX_ PTR_TBL_t *table)
{
    SV **svp = modperl_module_config_hash_get(aTHX_ TRUE);
    sv_setiv(*svp, (IV)table);
}

PTR_TBL_t *modperl_module_config_table_get(pTHX_ int create)
{
    PTR_TBL_t *table = NULL;

    SV *sv, **svp = modperl_module_config_hash_get(aTHX_ create);
    
    if (!svp) {
        return NULL;
    }

    sv = *svp;
    if (!SvIOK(sv) && create) {
        table = ptr_table_new();
        sv_setiv(sv, (IV)table);
    }
    else {
        table = (PTR_TBL_t *)SvIV(sv);
    }

    return table;
}

typedef struct {
    PerlInterpreter *perl;
    PTR_TBL_t *table;
    void *ptr;
} config_obj_cleanup_t;

/*
 * any per-dir CREATE or MERGE that happens at request time
 * needs to be removed from the pointer table.
 */
static apr_status_t modperl_module_config_obj_cleanup(void *data)
{
    config_obj_cleanup_t *cleanup =
        (config_obj_cleanup_t *)data;
    dTHXa(cleanup->perl);

    modperl_svptr_table_delete(aTHX_ cleanup->table, cleanup->ptr);

    MP_TRACE_c(MP_FUNC, "deleting ptr 0x%lx from table 0x%lx\n",
               (unsigned long)cleanup->ptr,
               (unsigned long)cleanup->table);

    return APR_SUCCESS;
}

static void modperl_module_config_obj_cleanup_register(pTHX_
                                                       apr_pool_t *p,
                                                       PTR_TBL_t *table,
                                                       void *ptr)
{
    config_obj_cleanup_t *cleanup =
        (config_obj_cleanup_t *)apr_palloc(p, sizeof(*cleanup));

    cleanup->table = table;
    cleanup->ptr = ptr;
#ifdef USE_ITHREADS
    cleanup->perl = aTHX;
#endif

    apr_pool_cleanup_register(p, cleanup,
                              modperl_module_config_obj_cleanup,
                              apr_pool_cleanup_null);
}

static void *modperl_module_config_merge(apr_pool_t *p,
                                         void *basev, void *addv,
                                         const char *method)
{
    GV *gv;

    modperl_module_cfg_t *mrg = NULL,
        *base = (modperl_module_cfg_t *)basev,
        *add  = (modperl_module_cfg_t *)addv,
        *tmp = base->server ? base : add;

    server_rec *s = tmp->server;
    int is_startup = (p == s->process->pconf);

#ifdef USE_ITHREADS
    modperl_interp_t *interp = modperl_interp_pool_select(p, s);
    dTHXa(interp->perl);
#endif

    PTR_TBL_t *table = modperl_module_config_table_get(aTHX_ TRUE);
    SV *mrg_obj = Nullsv,
        *base_obj = ptr_table_fetch(table, base),
        *add_obj  = ptr_table_fetch(table, add);

    HV *stash;

    if (!base_obj || (base_obj == add_obj)) {
        return add_obj;
    }

    stash = SvSTASH(SvRV(base_obj));

    MP_TRACE_c(MP_FUNC, "looking for method %s in package `%s'\n", 
               method, SvCLASS(base_obj));

    /* XXX: should do this lookup at startup time */
    if ((gv = gv_fetchmethod_autoload(stash, method, FALSE)) && isGV(gv)) {
        int count;
        dSP;

        mrg = modperl_module_cfg_new(p);
        memcpy(mrg, tmp, sizeof(*mrg));

        MP_TRACE_c(MP_FUNC, "calling %s->%s\n", SvCLASS(base_obj), method);

        ENTER;SAVETMPS;
        PUSHMARK(sp);
        XPUSHs(base_obj);XPUSHs(add_obj);

        PUTBACK;
        count = call_sv((SV*)GvCV(gv), G_EVAL|G_SCALAR);
        SPAGAIN;

        if (count == 1) {
            mrg_obj = SvREFCNT_inc(POPs);
        }

        PUTBACK;
        FREETMPS;LEAVE;

        if (SvTRUE(ERRSV)) {
            /* XXX: should die here. */
            (void)modperl_errsv(aTHX_ HTTP_INTERNAL_SERVER_ERROR,
                                NULL, NULL);
        }
    }
    else {
        mrg_obj = newSVsv(base_obj);
    }

    ptr_table_store(table, mrg, mrg_obj);

    if (!is_startup) {
        modperl_module_config_obj_cleanup_register(aTHX_ p, table, mrg);
    }

    return (void *)mrg;
}

static void *modperl_module_config_dir_merge(apr_pool_t *p,
                                             void *basev, void *addv)
{
    return modperl_module_config_merge(p, basev, addv, "DIR_MERGE");
}

static void *modperl_module_config_srv_merge(apr_pool_t *p,
                                             void *basev, void *addv)
{
    return modperl_module_config_merge(p, basev, addv, "SERVER_MERGE");
}

#define modperl_bless_cmd_parms(parms) \
    sv_2mortal(modperl_ptr2obj(aTHX_ "Apache::CmdParms", (void *)parms))

static const char *
modperl_module_config_get_obj(pTHX_
                              apr_pool_t *p,
                              PTR_TBL_t *table,
                              modperl_module_cfg_t *cfg,
                              modperl_module_cmd_data_t *info,
                              const char *method,
                              cmd_parms *parms,
                              SV **obj)
{
    HV *stash;
    GV *gv;
    int is_startup = (p == parms->server->process->pconf);

    /*
     * XXX: if MPM is not threaded, we could modify the
     * modperl_module_cfg_t * directly and avoid the ptr_table
     * altogether.
     */
    if ((*obj = (SV*)ptr_table_fetch(table, cfg))) {
        /* object already exists */
        return NULL;
    }

    MP_TRACE_c(MP_FUNC, "%s cfg=0x%lx for %s.%s\n",
               method, (unsigned long)cfg,
               info->modp->name,
               parms->cmd->name);

    cfg->name = info->modp->name;
    cfg->namelen = strlen(cfg->name);
    /* used by merge functions to get a Perl interp */
    cfg->server = parms->server;

    stash = gv_stashpvn(cfg->name, cfg->namelen, TRUE);

    /* return $class->type if $class->can(type) */
    /* XXX: should do this lookup at startup time */
    if ((gv = gv_fetchmethod_autoload(stash, method, FALSE)) && isGV(gv)) {
        int count;
        dSP;

        ENTER;SAVETMPS;
        PUSHMARK(sp);
        XPUSHs(sv_2mortal(newSVpv(cfg->name, cfg->namelen)));
        XPUSHs(modperl_bless_cmd_parms(parms));

        PUTBACK;
        count = call_sv((SV*)GvCV(gv), G_EVAL|G_SCALAR);
        SPAGAIN;

        if (count == 1) {
            *obj = SvREFCNT_inc(POPs);
        }

        PUTBACK;
        FREETMPS;LEAVE;

        if (SvTRUE(ERRSV)) {
            return SvPVX(ERRSV);
        }
    }
    else {
        /* return bless {}, $class */
        *obj = newRV_noinc((SV*)newHV());
        *obj = sv_bless(*obj, stash);
    }

    if (!is_startup) {
        modperl_module_config_obj_cleanup_register(aTHX_ p, table, cfg);
    }

    ptr_table_store(table, cfg, *obj);

    return NULL;
}

#define PUSH_STR_ARG(arg) \
    if (arg) XPUSHs(sv_2mortal(newSVpv(arg,0)))

static const char *modperl_module_cmd_TAKE123(cmd_parms *parms,
                                              modperl_module_cfg_t *cfg,
                                              const char *one,
                                              const char *two,
                                              const char *three)
{
    const char *retval = NULL, *errmsg;
    const command_rec *cmd = parms->cmd;
    server_rec *s = parms->server;
    apr_pool_t *p = parms->pool;
    modperl_module_cmd_data_t *info =
        (modperl_module_cmd_data_t *)cmd->cmd_data;
    modperl_module_cfg_t *srv_cfg;

#ifdef USE_ITHREADS
    modperl_interp_t *interp = modperl_interp_pool_select(p, s);
    dTHXa(interp->perl);
#endif

    int count;
    PTR_TBL_t *table = modperl_module_config_table_get(aTHX_ TRUE);
    SV *obj = Nullsv;
    dSP;

    errmsg = modperl_module_config_get_obj(aTHX_ p, table, cfg, info,
                                           "DIR_CREATE", parms, &obj);

    if (errmsg) {
        return errmsg;
    }

    if (obj) {
        MP_TRACE_c(MP_FUNC, "found per-dir obj=0x%lx for %s.%s\n",
                   (unsigned long)obj,
                   info->modp->name, cmd->name);
    }

    /* XXX: could delay creation of srv_obj until
     * Apache::ModuleConfig->get is called.
     */
    srv_cfg = ap_get_module_config(s->module_config, info->modp);

    if (srv_cfg) {
        SV *srv_obj;
        errmsg = modperl_module_config_get_obj(aTHX_ p, table, srv_cfg, info,
                                               "SERVER_CREATE", parms,
                                               &srv_obj);
        if (errmsg) {
            return errmsg;
        }

        if (srv_obj) {
            MP_TRACE_c(MP_FUNC, "found per-srv obj=0x%lx for %s.%s\n",
                       (unsigned long)srv_obj,
                       info->modp->name, cmd->name);
        }
    }

    ENTER;SAVETMPS;
    PUSHMARK(SP);
    EXTEND(SP, 2);

    PUSHs(obj);
    PUSHs(modperl_bless_cmd_parms(parms));

    if (cmd->args_how != NO_ARGS) {
        PUSH_STR_ARG(one);
        PUSH_STR_ARG(two);
        PUSH_STR_ARG(three);
    }

    PUTBACK;
    count = call_method(info->func_name, G_EVAL|G_SCALAR);
    SPAGAIN;

    if (count == 1) {
        if (strEQ(POPp, DECLINE_CMD)) {
            retval = DECLINE_CMD;
        }
    }

    PUTBACK;
    FREETMPS;LEAVE;

    if (SvTRUE(ERRSV)) {
        retval = SvPVX(ERRSV);
    }

    return retval;
}

static const char *modperl_module_cmd_TAKE1(cmd_parms *parms,
                                            modperl_module_cfg_t *cfg,
                                            const char *one)
{
    return modperl_module_cmd_TAKE123(parms, cfg, one, NULL, NULL);
}

static const char *modperl_module_cmd_TAKE2(cmd_parms *parms,
                                            modperl_module_cfg_t *cfg,
                                            const char *one,
                                            const char *two)
{
    return modperl_module_cmd_TAKE123(parms, cfg, one, two, NULL);
}

static const char *modperl_module_cmd_FLAG(cmd_parms *parms,
                                           modperl_module_cfg_t *cfg,
                                           int flag)
{
    char buf[2];

    apr_snprintf(buf, sizeof(buf), "%d", flag);

    return modperl_module_cmd_TAKE123(parms, cfg, buf, NULL, NULL);
}

#define modperl_module_cmd_RAW_ARGS modperl_module_cmd_TAKE1
#define modperl_module_cmd_NO_ARGS  modperl_module_cmd_TAKE1
#define modperl_module_cmd_ITERATE  modperl_module_cmd_TAKE1
#define modperl_module_cmd_ITERATE2 modperl_module_cmd_TAKE2
#define modperl_module_cmd_TAKE12   modperl_module_cmd_TAKE2
#define modperl_module_cmd_TAKE23   modperl_module_cmd_TAKE123
#define modperl_module_cmd_TAKE3    modperl_module_cmd_TAKE123
#define modperl_module_cmd_TAKE13   modperl_module_cmd_TAKE123

static cmd_func modperl_module_cmd_lookup(enum cmd_how args_how) {
    switch (args_how) {
      case RAW_ARGS:
        return modperl_module_cmd_RAW_ARGS;
      case TAKE1:
        return modperl_module_cmd_TAKE1;
      case TAKE2:
        return modperl_module_cmd_TAKE2;
      case ITERATE:
        return modperl_module_cmd_ITERATE;
      case ITERATE2:
        return modperl_module_cmd_ITERATE2;
      case FLAG:
        return modperl_module_cmd_FLAG;
      case NO_ARGS:
        return modperl_module_cmd_NO_ARGS;
      case TAKE12:
        return modperl_module_cmd_TAKE12;
      case TAKE3:
        return modperl_module_cmd_TAKE3;
      case TAKE23:
        return modperl_module_cmd_TAKE23;
      case TAKE123:
        return modperl_module_cmd_TAKE123;
      case TAKE13:
        return modperl_module_cmd_TAKE13;
    }

    return NULL;
}

static apr_status_t modperl_module_remove(void *data)
{
    module *modp = (module *)data;

    ap_remove_loaded_module(modp);

    return APR_SUCCESS;
}

static AV *modperl_module_cmds_get(pTHX_ module *modp)
{
    char *name = Perl_form(aTHX_ "%s::%s", modp->name,
                           "APACHE_MODULE_COMMANDS");
    return get_av(name, FALSE);
}

static const char *modperl_module_cmd_fetch(pTHX_ SV *obj,
                                            const char *name, SV **retval)
{
    const char *errmsg = NULL;

    *retval = Nullsv;

    if (sv_isobject(obj)) {
        int count;
        dSP;
        ENTER;SAVETMPS;
        PUSHMARK(SP);
        XPUSHs(obj);
        PUTBACK;

        count = call_method(name, G_EVAL|G_SCALAR);

        SPAGAIN;

        if (count == 1) {
            SV *sv = POPs;
            if (SvTRUE(sv)) {
                *retval = SvREFCNT_inc(sv);
            }
        }

        if (!*retval) {
            errmsg = Perl_form(aTHX_ "%s->%s did not return a %svalue",
                               SvCLASS(obj), name, count ? "true " : "");
        }

        PUTBACK;
        FREETMPS;LEAVE;
        
        if (SvTRUE(ERRSV)) {
            errmsg = SvPVX(ERRSV);
        }
    }
    else if (SvROK(obj) && (SvTYPE(SvRV(obj)) == SVt_PVHV)) {
        HV *hv = (HV*)SvRV(obj);
        SV **svp = hv_fetch(hv, name, strlen(name), 0);

        if (svp) {
            *retval = SvREFCNT_inc(*svp);
        }
        else {
            errmsg = Perl_form(aTHX_ "HASH key %s does not exist", name);
        }
    }
    else {
        errmsg = "command entry is not an object or a HASH reference";
    }

    return errmsg;
}

static const char *modperl_module_add_cmds(apr_pool_t *p, server_rec *s,
                                           module *modp)
{
    const char *errmsg;
    apr_array_header_t *cmds;
    command_rec *cmd;
    AV *module_cmds;
    I32 i, fill;
#ifdef USE_ITHREADS
    MP_dSCFG(s);
    dTHXa(scfg->mip->parent->perl);
#endif

    if (!(module_cmds = modperl_module_cmds_get(aTHX_ modp))) {
        return apr_pstrcat(p, "module ", modp->name,
                           " does not define @APACHE_MODULE_COMMANDS", NULL);
    }

    fill = AvFILL(module_cmds);
    cmds = apr_array_make(p, fill+1, sizeof(command_rec));

    for (i=0; i<=fill; i++) {
        SV *val;
        STRLEN len;
        SV *obj = AvARRAY(module_cmds)[i];
        modperl_module_cmd_data_t *info = modperl_module_cmd_data_new(p);

        info->modp = modp;

        cmd = apr_array_push(cmds);

        if ((errmsg = modperl_module_cmd_fetch(aTHX_ obj, "name", &val))) {
            return errmsg;
        }

        cmd->name = apr_pstrdup(p, SvPV(val, len));
        SvREFCNT_dec(val);

        if ((errmsg = modperl_module_cmd_fetch(aTHX_ obj, "args_how", &val))) {
            /* XXX default based on $self->func prototype */
            cmd->args_how = TAKE1; /* default */
        }
        else {
            cmd->args_how = SvIV(val);
            SvREFCNT_dec(val);
        }

        if (!(cmd->func = modperl_module_cmd_lookup(cmd->args_how))) {
            return apr_psprintf(p,
                                "no command function defined for args_how=%d",
                                cmd->args_how);
        }

        if ((errmsg = modperl_module_cmd_fetch(aTHX_ obj, "func", &val))) {
            info->func_name = cmd->name;  /* default */
        }
        else {
            info->func_name = apr_pstrdup(p, SvPV(val, len));
            SvREFCNT_dec(val);
        }

        if ((errmsg = modperl_module_cmd_fetch(aTHX_ obj, "req_override", &val))) {
            cmd->req_override = OR_ALL; /* default */
        }
        else {
            cmd->req_override = SvIV(val);
            SvREFCNT_dec(val);
        }

        if ((errmsg = modperl_module_cmd_fetch(aTHX_ obj, "errmsg", &val))) {
            /* default */
            /* XXX generate help msg based on args_how */
            cmd->errmsg = apr_pstrcat(p, cmd->name, " command", NULL);
        }
        else {
            cmd->errmsg = apr_pstrdup(p, SvPV(val, len));
            SvREFCNT_dec(val);
        }

        cmd->cmd_data = info;

        /* no default if undefined */
        if (!(errmsg = modperl_module_cmd_fetch(aTHX_ obj, "data", &val))) {
            info->cmd_data = apr_pstrdup(p, SvPV(val, len));
            SvREFCNT_dec(val);
        }
    }

    cmd = apr_array_push(cmds);
    cmd->name = NULL;

    modp->cmds = (command_rec *)cmds->elts;

    return NULL;
}

static void modperl_module_insert(module *modp)
{
    module *m;

    /*
     * insert after mod_perl, rather the top of the list.
     * (see ap_add_module; does not insert into ap_top_module list if
     *  m->next != NULL)
     * this way, modperl config merging happens before this module.
     */

    for (m = ap_top_module; m; m=m->next) {
        if (m == &perl_module) {
            module *next = m->next;
            m->next = modp;
            modp->next = next;
            break;
        }
    }
}

const char *modperl_module_add(apr_pool_t *p, server_rec *s,
                               const char *name)
{
    MP_dSCFG(s);
    const char *errmsg;
    module *modp = (module *)apr_pcalloc(p, sizeof(*modp));

    /* STANDARD20_MODULE_STUFF */
    modp->version       = MODULE_MAGIC_NUMBER_MAJOR;
    modp->minor_version = MODULE_MAGIC_NUMBER_MINOR;
    modp->module_index  = -1;
    modp->name          = apr_pstrdup(p, name);
    modp->magic         = MODULE_MAGIC_COOKIE;

    /* 
     * XXX: we should lookup here if the Perl methods exist,
     * and set these pointers only if they do.
     */
    modp->create_dir_config    = modperl_module_config_dir_create;
    modp->merge_dir_config     = modperl_module_config_dir_merge;
    modp->create_server_config = modperl_module_config_srv_create;
    modp->merge_server_config  = modperl_module_config_srv_merge;

    modp->cmds = NULL;

    if ((errmsg = modperl_module_add_cmds(p, s, modp))) {
        return errmsg;
    }

    modperl_module_insert(modp);

    ap_add_loaded_module(modp, p);

    apr_pool_cleanup_register(p, modp, modperl_module_remove,
                              apr_pool_cleanup_null);

    ap_single_module_configure(p, s, modp);

    if (!scfg->modules) {
        scfg->modules = apr_hash_make(p);
    }

    apr_hash_set(scfg->modules, name, APR_HASH_KEY_STRING, modp);

#ifdef USE_ITHREADS
    /* 
     * if the Perl module is loaded in the base server and a vhost
     * has configuration directives from that module, but no mod_perl.c
     * directives, scfg == NULL when modperl_module_cmd_TAKE123 is run.
     * this happens before server configs are merged, so we stash a pointer
     * to what will be merged as the parent interp later. i.e. "safe hack"
     */
    if (!modperl_interp_pool_get(p)) {
        /* for vhosts */
        modperl_interp_pool_set(p, scfg->mip->parent, FALSE);
    }
#endif

    return NULL;
}
