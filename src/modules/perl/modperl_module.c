/* Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "mod_perl.h"

typedef struct {
    modperl_mgv_t *dir_create;
    modperl_mgv_t *dir_merge;
    modperl_mgv_t *srv_create;
    modperl_mgv_t *srv_merge;
    int namelen;
} modperl_module_info_t;

typedef struct {
    server_rec *server;
    modperl_module_info_t *minfo;
} modperl_module_cfg_t;

#define MP_MODULE_INFO(modp) \
    (modperl_module_info_t *)modp->dynamic_load_handle

#define MP_MODULE_CFG_MINFO(ptr) \
    ((modperl_module_cfg_t *)ptr)->minfo

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
    sv_setiv(*svp, PTR2IV(table));
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
        table = modperl_svptr_table_new(aTHX);
        sv_setiv(sv, PTR2IV(table));
    }
    else {
        table = INT2PTR(PTR_TBL_t *, SvIV(sv));
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

    MP_TRACE_c(MP_FUNC, "deleting ptr 0x%lx from table 0x%lx",
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

#define MP_CFG_MERGE_DIR 1
#define MP_CFG_MERGE_SRV 2

/*
 * XXX: vhosts may have different parent interpreters.
 */
static void *modperl_module_config_merge(apr_pool_t *p,
                                         void *basev, void *addv,
                                         int type)
{
    GV *gv;
    modperl_mgv_t *method;
    modperl_module_cfg_t *mrg = NULL,
        *tmp,
        *base = (modperl_module_cfg_t *)basev,
        *add  = (modperl_module_cfg_t *)addv;
    server_rec *s;
    int is_startup;
    PTR_TBL_t *table;
    SV *mrg_obj = (SV *)NULL, *base_obj, *add_obj;
#ifdef USE_ITHREADS
    modperl_interp_t *interp;
    MP_PERL_CONTEXT_DECLARE;
#endif

    /* if the module is loaded in vhost, base==NULL */
    tmp = (base && base->server) ? base : add;

    if (tmp && !tmp->server) {
        /* no directives for this module were encountered so far */
        return basev;
    }

    s = tmp->server;
    is_startup = (p == s->process->pconf);

#ifdef USE_ITHREADS
    interp = modperl_interp_pool_select(p, s);
    MP_PERL_CONTEXT_STORE_OVERRIDE(interp->perl);
#endif

    table = modperl_module_config_table_get(aTHX_ TRUE);
    base_obj = modperl_svptr_table_fetch(aTHX_ table, base);
    add_obj  = modperl_svptr_table_fetch(aTHX_ table, add);

    if (!base_obj || (base_obj == add_obj)) {
#ifdef USE_ITHREADS
        /* XXX: breaks prefork
           modperl_interp_unselect(interp); */
        MP_PERL_CONTEXT_RESTORE;
#endif
        return addv;
    }

    mrg = modperl_module_cfg_new(p);
    memcpy(mrg, tmp, sizeof(*mrg));

    method = (type == MP_CFG_MERGE_DIR) ?
        mrg->minfo->dir_merge :
        mrg->minfo->srv_merge;

    if (method && (gv = modperl_mgv_lookup(aTHX_ method))) {
        int count;
        dSP;

        MP_TRACE_c(MP_FUNC, "calling %s->%s",
                   SvCLASS(base_obj), modperl_mgv_last_name(method));

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
        mrg_obj = SvREFCNT_inc(add_obj);
    }

    modperl_svptr_table_store(aTHX_ table, mrg, mrg_obj);

    if (!is_startup) {
        modperl_module_config_obj_cleanup_register(aTHX_ p, table, mrg);
    }

#ifdef USE_ITHREADS
    /* XXX: breaks prefork
       modperl_interp_unselect(interp); */
    MP_PERL_CONTEXT_RESTORE;
#endif

    return (void *)mrg;
}

static void *modperl_module_config_dir_merge(apr_pool_t *p,
                                             void *basev, void *addv)
{
    return modperl_module_config_merge(p, basev, addv,
                                       MP_CFG_MERGE_DIR);
}

static void *modperl_module_config_srv_merge(apr_pool_t *p,
                                             void *basev, void *addv)
{
    return modperl_module_config_merge(p, basev, addv,
                                       MP_CFG_MERGE_SRV);
}

#define modperl_bless_cmd_parms(parms) \
    sv_2mortal(modperl_ptr2obj(aTHX_ "Apache2::CmdParms", (void *)parms))

static const char *
modperl_module_config_create_obj(pTHX_
                                 apr_pool_t *p,
                                 PTR_TBL_t *table,
                                 modperl_module_cfg_t *cfg,
                                 modperl_module_cmd_data_t *info,
                                 modperl_mgv_t *method,
                                 cmd_parms *parms,
                                 SV **obj)
{
    const char *mname = info->modp->name;
    modperl_module_info_t *minfo = MP_MODULE_INFO(info->modp);
    GV *gv;
    int is_startup = (p == parms->server->process->pconf);

    /*
     * XXX: if MPM is not threaded, we could modify the
     * modperl_module_cfg_t * directly and avoid the ptr_table
     * altogether.
     */
    if ((*obj = (SV*)modperl_svptr_table_fetch(aTHX_ table, cfg))) {
        /* object already exists */
        return NULL;
    }

    MP_TRACE_c(MP_FUNC, "%s cfg=0x%lx for %s.%s",
               method ? modperl_mgv_last_name(method) : "NULL",
               (unsigned long)cfg, mname, parms->cmd->name);

    /* used by merge functions to get a Perl interp */
    cfg->server = parms->server;
    cfg->minfo = minfo;

    if (method && (gv = modperl_mgv_lookup(aTHX_ method))) {
        int count;
        dSP;

        ENTER;SAVETMPS;
        PUSHMARK(sp);
        XPUSHs(sv_2mortal(newSVpv(mname, minfo->namelen)));
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
        HV *stash = gv_stashpvn(mname, minfo->namelen, FALSE);
        /* return bless {}, $class */
        *obj = newRV_noinc((SV*)newHV());
        *obj = sv_bless(*obj, stash);
    }

    if (!is_startup) {
        modperl_module_config_obj_cleanup_register(aTHX_ p, table, cfg);
    }

    modperl_svptr_table_store(aTHX_ table, cfg, *obj);

    return NULL;
}

#define PUSH_STR_ARG(arg) \
    if (arg) XPUSHs(sv_2mortal(newSVpv(arg,0)))

static const char *modperl_module_cmd_take123(cmd_parms *parms,
                                              void *mconfig,
                                              const char *one,
                                              const char *two,
                                              const char *three)
{
    modperl_module_cfg_t *cfg = (modperl_module_cfg_t *)mconfig;
    const char *retval = NULL, *errmsg;
    const command_rec *cmd = parms->cmd;
    server_rec *s = parms->server;
    apr_pool_t *p = parms->pool;
    modperl_module_cmd_data_t *info =
        (modperl_module_cmd_data_t *)cmd->cmd_data;
    modperl_module_info_t *minfo = MP_MODULE_INFO(info->modp);
    modperl_module_cfg_t *srv_cfg;
    int modules_alias = 0;

#ifdef USE_ITHREADS
    modperl_interp_t *interp = modperl_interp_pool_select(p, s);
    dTHXa(interp->perl);
#endif

    int count;
    PTR_TBL_t *table = modperl_module_config_table_get(aTHX_ TRUE);
    SV *obj = (SV *)NULL;
    dSP;

    if (s->is_virtual) {
        MP_dSCFG(s);

        /* if the Perl module is loaded in the base server and a vhost
         * has configuration directives from that module, but no
         * mod_perl.c directives, scfg == NULL when
         * modperl_module_cmd_take123 is run. If the directive
         * callback wants to do something with the mod_perl config
         * object, it'll segfault, since it doesn't exist yet, because
         * this happens before server configs are merged. So we create
         * a temp struct and fill it in with things that might be
         * needed by the Perl callback.
         */
        if (!scfg) {
            scfg = modperl_config_srv_new(p, s);
            modperl_set_module_config(s->module_config, scfg);
            scfg->server = s;
        }

        /* if PerlLoadModule Foo is called from the base server, but
         * Foo's directives are used inside a vhost, we need to
         * temporary link to the base server config's 'modules'
         * member. e.g. so Apache2::Module->get_config() can be called
         * from a custom directive's callback, before the server/vhost
         * config merge is performed
         */
        if (!scfg->modules) {
            modperl_config_srv_t *base_scfg =
                modperl_config_srv_get(modperl_global_get_server_rec());
            if (base_scfg->modules) {
                scfg->modules = base_scfg->modules;
                modules_alias = 1;
            }
        }

    }

    errmsg = modperl_module_config_create_obj(aTHX_ p, table, cfg, info,
                                              minfo->dir_create,
                                              parms, &obj);

    if (errmsg) {
        return errmsg;
    }

    if (obj) {
        MP_TRACE_c(MP_FUNC, "found per-dir obj=0x%lx for %s.%s",
                   (unsigned long)obj,
                   info->modp->name, cmd->name);
    }

    /* XXX: could delay creation of srv_obj until
     * Apache2::ModuleConfig->get is called.
     */
    srv_cfg = ap_get_module_config(s->module_config, info->modp);

    if (srv_cfg) {
        SV *srv_obj;
        errmsg = modperl_module_config_create_obj(aTHX_ p, table, srv_cfg, info,
                                               minfo->srv_create,
                                               parms, &srv_obj);
        if (errmsg) {
            return errmsg;
        }

        if (srv_obj) {
            MP_TRACE_c(MP_FUNC, "found per-srv obj=0x%lx for %s.%s",
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
        SV *sv = POPs;
        if (SvPOK(sv) && strEQ(SvPVX(sv), DECLINE_CMD)) {
            retval = DECLINE_CMD;
        }
    }

    PUTBACK;
    FREETMPS;LEAVE;

    if (SvTRUE(ERRSV)) {
        retval = SvPVX(ERRSV);
    }

    if (modules_alias) {
        MP_dSCFG(s);
        /* unalias the temp aliasing */
        scfg->modules = NULL;
    }

    return retval;
}

static const char *modperl_module_cmd_take1(cmd_parms *parms,
                                            void *mconfig,
                                            const char *one)
{
    return modperl_module_cmd_take123(parms, mconfig, one, NULL, NULL);
}

static const char *modperl_module_cmd_take2(cmd_parms *parms,
                                            void *mconfig,
                                            const char *one,
                                            const char *two)
{
    return modperl_module_cmd_take123(parms, mconfig, one, two, NULL);
}

static const char *modperl_module_cmd_flag(cmd_parms *parms,
                                           void *mconfig,
                                           int flag)
{
    char buf[2];

    apr_snprintf(buf, sizeof(buf), "%d", flag);

    return modperl_module_cmd_take123(parms, mconfig, buf, NULL, NULL);
}

static const char *modperl_module_cmd_no_args(cmd_parms *parms,
                                              void *mconfig)
{
    return modperl_module_cmd_take123(parms, mconfig, NULL, NULL, NULL);
}

#define modperl_module_cmd_raw_args modperl_module_cmd_take1
#define modperl_module_cmd_iterate  modperl_module_cmd_take1
#define modperl_module_cmd_iterate2 modperl_module_cmd_take2
#define modperl_module_cmd_take12   modperl_module_cmd_take2
#define modperl_module_cmd_take23   modperl_module_cmd_take123
#define modperl_module_cmd_take3    modperl_module_cmd_take123
#define modperl_module_cmd_take13   modperl_module_cmd_take123

#if defined(AP_HAVE_DESIGNATED_INITIALIZER)
#   define modperl_module_cmd_func_set(cmd, name) \
    cmd->func.name = modperl_module_cmd_##name
#else
#   define modperl_module_cmd_func_set(cmd, name) \
    cmd->func = modperl_module_cmd_##name
#endif

static int modperl_module_cmd_lookup(command_rec *cmd)
{
    switch (cmd->args_how) {
      case TAKE1:
      case ITERATE:
        modperl_module_cmd_func_set(cmd, take1);
        break;
      case TAKE2:
      case ITERATE2:
      case TAKE12:
        modperl_module_cmd_func_set(cmd, take2);
        break;
      case TAKE3:
      case TAKE23:
      case TAKE123:
      case TAKE13:
        modperl_module_cmd_func_set(cmd, take3);
        break;
      case RAW_ARGS:
        modperl_module_cmd_func_set(cmd, raw_args);
        break;
      case FLAG:
        modperl_module_cmd_func_set(cmd, flag);
        break;
      case NO_ARGS:
        modperl_module_cmd_func_set(cmd, no_args);
        break;
      default:
        return FALSE;
    }

    return TRUE;
}

static apr_status_t modperl_module_remove(void *data)
{
    module *modp = (module *)data;

    ap_remove_loaded_module(modp);

    return APR_SUCCESS;
}

static const char *modperl_module_cmd_fetch(pTHX_ SV *obj,
                                            const char *name, SV **retval)
{
    const char *errmsg = NULL;

    if (*retval) {
        SvREFCNT_dec(*retval);
        *retval = (SV *)NULL;
    }

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
                                           module *modp, SV *mod_cmds)
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
    module_cmds = (AV*)SvRV(mod_cmds);

    fill = AvFILL(module_cmds);
    cmds = apr_array_make(p, fill+1, sizeof(command_rec));

    for (i=0; i<=fill; i++) {
        SV *val = (SV *)NULL;
        STRLEN len;
        SV *obj = AvARRAY(module_cmds)[i];
        modperl_module_cmd_data_t *info = modperl_module_cmd_data_new(p);

        info->modp = modp;

        cmd = apr_array_push(cmds);

        if ((errmsg = modperl_module_cmd_fetch(aTHX_ obj, "name", &val))) {
            return errmsg;
        }

        cmd->name = apr_pstrdup(p, SvPV(val, len));

        if ((errmsg = modperl_module_cmd_fetch(aTHX_ obj, "args_how", &val))) {
            /* XXX default based on $self->func prototype */
            cmd->args_how = TAKE1; /* default */
        }
        else {
            if (SvIOK(val)) {
                cmd->args_how = SvIV(val);
            }
            else {
                cmd->args_how =
                    SvIV(modperl_constants_lookup_apache2_const(aTHX_ SvPV(val, len)));
            }
        }

        if (!modperl_module_cmd_lookup(cmd)) {
            return apr_psprintf(p,
                                "no command function defined for args_how=%d",
                                cmd->args_how);
        }

        if ((errmsg = modperl_module_cmd_fetch(aTHX_ obj, "func", &val))) {
            info->func_name = cmd->name;  /* default */
        }
        else {
            info->func_name = apr_pstrdup(p, SvPV(val, len));
        }

        if ((errmsg = modperl_module_cmd_fetch(aTHX_ obj, "req_override", &val))) {
            cmd->req_override = OR_ALL; /* default */
        }
        else {
            if (SvIOK(val)) {
                cmd->req_override = SvIV(val);
            }
            else {
                cmd->req_override =
                    SvIV(modperl_constants_lookup_apache2_const(aTHX_ SvPV(val, len)));
            }
        }

        if ((errmsg = modperl_module_cmd_fetch(aTHX_ obj, "errmsg", &val))) {
            /* default */
            /* XXX generate help msg based on args_how */
            cmd->errmsg = apr_pstrcat(p, cmd->name, " command", NULL);
        }
        else {
            cmd->errmsg = apr_pstrdup(p, SvPV(val, len));
        }

        cmd->cmd_data = info;

        /* no default if undefined */
        if (!(errmsg = modperl_module_cmd_fetch(aTHX_ obj, "cmd_data", &val))) {
            info->cmd_data = apr_pstrdup(p, SvPV(val, len));
        }

        if (val) {
            SvREFCNT_dec(val);
            val = (SV *)NULL;
        }
    }

    cmd = apr_array_push(cmds);
    cmd->name = NULL;

    modp->cmds = (command_rec *)cmds->elts;

    return NULL;
}

static void modperl_module_insert(module *modp)
{
    /*
     * insert after mod_perl, rather the top of the list.
     * (see ap_add_module; does not insert into ap_top_module list if
     *  m->next != NULL)
     * this way, modperl config merging happens before this module.
     */

    modp->next = perl_module.next;
    perl_module.next = modp;
}

#define MP_isGV(gv) (gv && isGV(gv))

static modperl_mgv_t *modperl_module_fetch_method(pTHX_
                                                  apr_pool_t *p,
                                                  module *modp,
                                                  const char *method)
{
    modperl_mgv_t *mgv;

    HV *stash = gv_stashpv(modp->name, FALSE);
    GV *gv = gv_fetchmethod_autoload(stash, method, FALSE);

    MP_TRACE_c(MP_FUNC, "looking for method %s in package `%s'...%sfound",
               method, modp->name,
               MP_isGV(gv) ? "" : "not ");

    if (!MP_isGV(gv)) {
        return NULL;
    }

    mgv = modperl_mgv_compile(aTHX_ p,
                              apr_pstrcat(p,
                                          modp->name, "::", method, NULL));

    return mgv;
}

const char *modperl_module_add(apr_pool_t *p, server_rec *s,
                               const char *name, SV *mod_cmds)
{
    MP_dSCFG(s);
#ifdef USE_ITHREADS
    dTHXa(scfg->mip->parent->perl);
#endif
    const char *errmsg;
    module *modp = (module *)apr_pcalloc(p, sizeof(*modp));
    modperl_module_info_t *minfo =
        (modperl_module_info_t *)apr_pcalloc(p, sizeof(*minfo));

    /* STANDARD20_MODULE_STUFF */
    modp->version       = MODULE_MAGIC_NUMBER_MAJOR;
    modp->minor_version = MODULE_MAGIC_NUMBER_MINOR;
    modp->module_index  = -1;
    modp->name          = apr_pstrdup(p, name);
    modp->magic         = MODULE_MAGIC_COOKIE;

    /* use this slot for our context */
    modp->dynamic_load_handle = minfo;

    /*
     * XXX: we should lookup here if the Perl methods exist,
     * and set these pointers only if they do.
     */
    modp->create_dir_config    = modperl_module_config_dir_create;
    modp->merge_dir_config     = modperl_module_config_dir_merge;
    modp->create_server_config = modperl_module_config_srv_create;
    modp->merge_server_config  = modperl_module_config_srv_merge;

    minfo->namelen = strlen(name);

    minfo->dir_create =
        modperl_module_fetch_method(aTHX_ p, modp, "DIR_CREATE");

    minfo->dir_merge =
        modperl_module_fetch_method(aTHX_ p, modp, "DIR_MERGE");

    minfo->srv_create =
        modperl_module_fetch_method(aTHX_ p, modp, "SERVER_CREATE");

    minfo->srv_merge =
        modperl_module_fetch_method(aTHX_ p, modp, "SERVER_MERGE");

    modp->cmds = NULL;

    if ((errmsg = modperl_module_add_cmds(p, s, modp, mod_cmds))) {
        return errmsg;
    }

    modperl_module_insert(modp);

    mp_add_loaded_module(modp, p, modp->name);

    apr_pool_cleanup_register(p, modp, modperl_module_remove,
                              apr_pool_cleanup_null);

    ap_single_module_configure(p, s, modp);

    if (!scfg->modules) {
        scfg->modules = apr_hash_make(p);
    }

    apr_hash_set(scfg->modules, apr_pstrdup(p, name), APR_HASH_KEY_STRING, modp);

#ifdef USE_ITHREADS
    /*
     * if the Perl module is loaded in the base server and a vhost
     * has configuration directives from that module, but no mod_perl.c
     * directives, scfg == NULL when modperl_module_cmd_take123 is run.
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

SV *modperl_module_config_get_obj(pTHX_ SV *pmodule, server_rec *s,
                                  ap_conf_vector_t *v)
{
    MP_dSCFG(s);
    module *modp;
    const char *name;
    void *ptr;
    PTR_TBL_t *table;
    SV *obj;

    if (!v) {
        v = s->module_config;
    }

    if (SvROK(pmodule)) {
        name = SvCLASS(pmodule);
    }
    else {
        STRLEN n_a;
        name = SvPV(pmodule, n_a);
    }

    if (!(scfg->modules &&
          (modp = apr_hash_get(scfg->modules, name, APR_HASH_KEY_STRING)))) {
        return &PL_sv_undef;
    }

    if (!(ptr = ap_get_module_config(v, modp))) {
        return &PL_sv_undef;
    }

    if (!(table = modperl_module_config_table_get(aTHX_ FALSE))) {
        return &PL_sv_undef;
    }

    if (!(obj = modperl_svptr_table_fetch(aTHX_ table, ptr))) {
        return &PL_sv_undef;
    }

    return obj;
}
