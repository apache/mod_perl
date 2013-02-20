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

/* This ensures that a given directive is either in Server context
 * or in a .htaccess file, usefull for things like PerlRequire
 */
#define MP_CHECK_SERVER_OR_HTACCESS_CONTEXT                            \
    if (parms->path && (parms->override & ACCESS_CONF)) {              \
        ap_directive_t *d = parms->directive;                          \
        return apr_psprintf(parms->pool,                               \
                            "%s directive not allowed in a %s> block", \
                            d->directive,                              \
                            d->parent->directive);                     \
    }

static char *modperl_cmd_unclosed_directive(cmd_parms *parms)
{
    return apr_pstrcat(parms->pool, parms->cmd->name,
                       "> directive missing closing '>'", NULL);
}

static char *modperl_cmd_too_late(cmd_parms *parms)
{
    return apr_pstrcat(parms->pool, "mod_perl is already running, "
                       "too late for ", parms->cmd->name, NULL);
}

char *modperl_cmd_push_handlers(MpAV **handlers, const char *name,
                                apr_pool_t *p)
{
    modperl_handler_t *h = modperl_handler_new(p, name);

    if (!*handlers) {
        *handlers = modperl_handler_array_new(p);
        MP_TRACE_d(MP_FUNC, "created handler stack");
    }

    /* XXX parse_handler if Perl is running */

    modperl_handler_array_push(*handlers, h);
    MP_TRACE_d(MP_FUNC, "pushed handler: %s", h->name);

    return NULL;
}

char *modperl_cmd_push_filter_handlers(MpAV **handlers,
                                       const char *name,
                                       apr_pool_t *p)
{
    modperl_handler_t *h = modperl_handler_new(p, name);

    /* filter modules need to be autoloaded, because their attributes
     * need to be known long before the callback is issued
     */
    if (*name == '-') {
        MP_TRACE_h(MP_FUNC,
                   "[%s] warning: filter handler %s will be not autoloaded. "
                   "Unless the module defining this handler is explicitly "
                   "preloaded, filter attributes will be ignored.\n",
                   modperl_pid_tid(p), h->name);
    }
    else {
        MpHandlerAUTOLOAD_On(h);
        MP_TRACE_h(MP_FUNC,
                   "[%s] filter handler %s will be autoloaded (to make "
                   "the filter attributes available)\n",
                   modperl_pid_tid(p), h->name);
    }

    if (!*handlers) {
        *handlers = modperl_handler_array_new(p);
        MP_TRACE_d(MP_FUNC, "created handler stack");
    }

    modperl_handler_array_push(*handlers, h);
    MP_TRACE_d(MP_FUNC, "pushed httpd filter handler: %s", h->name);

    return NULL;
}

static char *modperl_cmd_push_httpd_filter_handlers(MpAV **handlers,
                                                    const char *name,
                                                    apr_pool_t *p)
{
    modperl_handler_t *h = modperl_handler_new(p, name);

    /* this is not a real mod_perl handler, we just re-use the
     * handlers structure to be able to mix mod_perl and non-mod_perl
     * filters */
    MpHandlerFAKE_On(h);
    h->attrs = MP_FILTER_HTTPD_HANDLER;

    if (!*handlers) {
        *handlers = modperl_handler_array_new(p);
        MP_TRACE_d(MP_FUNC, "created handler stack");
    }

    modperl_handler_array_push(*handlers, h);
    MP_TRACE_d(MP_FUNC, "pushed httpd filter handler: %s", h->name);

    return NULL;
}


#define MP_CMD_SRV_TRACE \
    MP_TRACE_d(MP_FUNC, "%s %s", parms->cmd->name, arg)

#define MP_CMD_SRV_CHECK \
MP_CMD_SRV_TRACE; \
{ \
    const char *err = ap_check_cmd_context(parms, GLOBAL_ONLY); \
    if (err) return err; \
}

MP_CMD_SRV_DECLARE(trace)
{
    MP_CMD_SRV_CHECK;
    modperl_trace_level_set_apache(parms->server, arg);
    return NULL;
}

/* this test shows whether the perl for the current s is running
 * (either base or vhost) */
static int modperl_vhost_is_running(server_rec *s)
{
#ifdef USE_ITHREADS
    if (s->is_virtual){
        MP_dSCFG(s);
        return scfg->mip ? TRUE : FALSE;
    }
#endif

    return modperl_is_running();

}

MP_CMD_SRV_DECLARE(switches)
{
    server_rec *s = parms->server;
    MP_dSCFG(s);
    if (modperl_vhost_is_running(s)) {
        return modperl_cmd_too_late(parms);
    }
    MP_TRACE_d(MP_FUNC, "arg = %s", arg);

    if (!strncasecmp(arg, "+inherit", 8)) {
        modperl_cmd_options(parms, mconfig, "+InheritSwitches");
    }
    else {
        modperl_config_srv_argv_push(arg);
    }
    return NULL;
}

MP_CMD_SRV_DECLARE(modules)
{
    MP_dSCFG(parms->server);
    modperl_config_dir_t *dcfg = (modperl_config_dir_t *)mconfig;
    MP_PERL_CONTEXT_DECLARE;

    MP_CHECK_SERVER_OR_HTACCESS_CONTEXT;

    if (modperl_is_running() &&
        modperl_init_vhost(parms->server, parms->pool, NULL) != OK)
    {
        return "init mod_perl vhost failed";
    }

    if (modperl_is_running()) {
        char *error = NULL;

        MP_TRACE_d(MP_FUNC, "load PerlModule %s", arg);

        MP_PERL_CONTEXT_STORE_OVERRIDE(scfg->mip->parent->perl);
        if (!modperl_require_module(aTHX_ arg, FALSE)) {
            error = SvPVX(ERRSV);
        }
        else {
            modperl_env_sync_srv_env_hash2table(aTHX_ parms->pool, scfg);
            modperl_env_sync_dir_env_hash2table(aTHX_ parms->pool, dcfg);
        }
        MP_PERL_CONTEXT_RESTORE;

        return error;
    }
    else {
        MP_TRACE_d(MP_FUNC, "push PerlModule %s", arg);
        *(const char **)apr_array_push(scfg->PerlModule) = arg;
        return NULL;
    }
}

MP_CMD_SRV_DECLARE(requires)
{
    MP_dSCFG(parms->server);
    modperl_config_dir_t *dcfg = (modperl_config_dir_t *)mconfig;
    MP_PERL_CONTEXT_DECLARE;

    MP_CHECK_SERVER_OR_HTACCESS_CONTEXT;

    if (modperl_is_running() &&
        modperl_init_vhost(parms->server, parms->pool, NULL) != OK)
    {
        return "init mod_perl vhost failed";
    }

    if (modperl_is_running()) {
        char *error = NULL;

        MP_TRACE_d(MP_FUNC, "load PerlRequire %s", arg);

        MP_PERL_CONTEXT_STORE_OVERRIDE(scfg->mip->parent->perl);
        if (!modperl_require_file(aTHX_ arg, FALSE)) {
            error = SvPVX(ERRSV);
        }
        else {
            modperl_env_sync_srv_env_hash2table(aTHX_ parms->pool, scfg);
            modperl_env_sync_dir_env_hash2table(aTHX_ parms->pool, dcfg);
        }
        MP_PERL_CONTEXT_RESTORE;

        return error;
    }
    else {
        MP_TRACE_d(MP_FUNC, "push PerlRequire %s", arg);
        *(const char **)apr_array_push(scfg->PerlRequire) = arg;
        return NULL;
    }
}

MP_CMD_SRV_DECLARE(config_requires)
{
    /* we must init earlier than normal */
    modperl_run();

    /* PerlConfigFile is only different from PerlRequires by forcing
     * an immediate init.
     */
    return modperl_cmd_requires(parms, mconfig, arg);
}

MP_CMD_SRV_DECLARE(post_config_requires)
{
    apr_pool_t *p = parms->temp_pool;
    modperl_config_dir_t *dcfg = (modperl_config_dir_t *)mconfig;
    MP_dSCFG(parms->server);

    modperl_require_file_t *require = apr_pcalloc(p, sizeof(*require));
    MP_TRACE_d(MP_FUNC, "push PerlPostConfigRequire for %s", arg);
    require->file = arg;
    require->dcfg = dcfg;

    *(modperl_require_file_t **)
        apr_array_push(scfg->PerlPostConfigRequire) = require;

    return NULL;
}

static void modperl_cmd_addvar_func(apr_table_t *configvars,
                                    apr_table_t *setvars,
                                    const char *key, const char *val)
{
    apr_table_addn(configvars, key, val);
}

/*  Conceptually, setvar is { unsetvar; addvar; } */

static void modperl_cmd_setvar_func(apr_table_t *configvars,
                                    apr_table_t *setvars,
                                    const char * key, const char *val)
{
    apr_table_setn(setvars, key, val);
    apr_table_setn(configvars, key, val);
}

static const char *modperl_cmd_modvar(modperl_var_modify_t varfunc,
                                      cmd_parms *parms,
                                      modperl_config_dir_t *dcfg,
                                      const char *arg1, const char *arg2)
{
    varfunc(dcfg->configvars, dcfg->setvars, arg1, arg2);

    MP_TRACE_d(MP_FUNC, "%s DIR: arg1 = %s, arg2 = %s",
               parms->cmd->name, arg1, arg2);

    /* make available via Apache2->server->dir_config */
    if (!parms->path) {
        MP_dSCFG(parms->server);
        varfunc(scfg->configvars, scfg->setvars, arg1, arg2);

        MP_TRACE_d(MP_FUNC, "%s SRV: arg1 = %s, arg2 = %s",
                   parms->cmd->name, arg1, arg2);
    }

    return NULL;
}

MP_CMD_SRV_DECLARE2(add_var)
{
    modperl_config_dir_t *dcfg = (modperl_config_dir_t *)mconfig;
    return modperl_cmd_modvar(modperl_cmd_addvar_func, parms, dcfg, arg1, arg2);
}

MP_CMD_SRV_DECLARE2(set_var)
{
    modperl_config_dir_t *dcfg = (modperl_config_dir_t *)mconfig;
    return modperl_cmd_modvar(modperl_cmd_setvar_func, parms, dcfg, arg1, arg2);
}

MP_CMD_SRV_DECLARE2(set_env)
{
    MP_dSCFG(parms->server);
    modperl_config_dir_t *dcfg = (modperl_config_dir_t *)mconfig;

#ifdef ENV_IS_CASELESS /* i.e. WIN32 */
    /* we turn off env magic during hv_store later, so do this now,
     * else lookups on keys with lowercase characters will fails
     * because Perl will uppercase them prior to lookup.
     */
    modperl_str_toupper((char *)arg1);
#endif

    MP_TRACE_d(MP_FUNC, "arg1 = %s, arg2 = %s", arg1, arg2);

    if (!parms->path) {
        /* will be propagated to environ */
        apr_table_setn(scfg->SetEnv, arg1, arg2);
        /* sync SetEnv => %ENV only for the top-level values */
        if (modperl_vhost_is_running(parms->server)) {
            MP_PERL_CONTEXT_DECLARE;
            MP_PERL_CONTEXT_STORE_OVERRIDE(scfg->mip->parent->perl);
            modperl_env_hv_store(aTHX_ arg1, arg2);
            MP_PERL_CONTEXT_RESTORE;
        }
    }

    apr_table_setn(dcfg->SetEnv, arg1, arg2);

    return NULL;
}

MP_CMD_SRV_DECLARE(pass_env)
{
    MP_dSCFG(parms->server);
    char *val = getenv(arg);

#ifdef ENV_IS_CASELESS /* i.e. WIN32 */
    /* we turn off env magic during hv_store later, so do this now,
     * else lookups on keys with lowercase characters will fails
     * because Perl will uppercase them prior to lookup.
     */
    modperl_str_toupper((char *)arg);
#endif

    if (val) {
        apr_table_setn(scfg->PassEnv, arg, apr_pstrdup(parms->pool, val));
        if (modperl_vhost_is_running(parms->server)) {
            MP_PERL_CONTEXT_DECLARE;
            MP_PERL_CONTEXT_STORE_OVERRIDE(scfg->mip->parent->perl);
            modperl_env_hv_store(aTHX_ arg, val);
            MP_PERL_CONTEXT_RESTORE;
        }
        MP_TRACE_d(MP_FUNC, "arg = %s, val = %s", arg, val);
    }
    else {
        MP_TRACE_d(MP_FUNC, "arg = %s: not found via getenv()", arg);
    }

    return NULL;
}

MP_CMD_SRV_DECLARE(options)
{
    MP_dSCFG(parms->server);
    modperl_config_dir_t *dcfg = (modperl_config_dir_t *)mconfig;
    int is_per_dir = parms->path ? 1 : 0;
    modperl_options_t *opts = is_per_dir ? dcfg->flags : scfg->flags;
    apr_pool_t *p = parms->temp_pool;
    const char *error;

    MP_TRACE_d(MP_FUNC, "arg = %s", arg);
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

static const char *modperl_cmd_parse_args(apr_pool_t *p,
                                          const char *args,
                                          apr_table_t **t)
{
    const char *orig_args = args;
    char *pair, *key, *val;
    *t = apr_table_make(p, 2);

    while (*(pair = ap_getword(p, &args, ',')) != '\0') {
        key = ap_getword_nc(p, &pair, '=');
        val = pair;

        if (!(*key && *val)) {
            return apr_pstrcat(p, "invalid args spec: ",
                               orig_args, NULL);
        }

        apr_table_set(*t, key, val);
    }

    return NULL;
}

MP_CMD_SRV_DECLARE(perl)
{
    apr_pool_t *p = parms->pool;
    const char *endp = ap_strrchr_c(arg, '>');
    const char *errmsg;
    char *code = "";
    char line[MAX_STRING_LEN];
    apr_table_t *args;
    ap_directive_t **current = mconfig;
    int line_num;

    if (!endp) {
        return modperl_cmd_unclosed_directive(parms);
    }

    MP_CHECK_SERVER_OR_HTACCESS_CONTEXT;

    arg = apr_pstrndup(p, arg, endp - arg);

    if ((errmsg = modperl_cmd_parse_args(p, arg, &args))) {
        return errmsg;
    }

    line_num = parms->config_file->line_number+1;
    while (!ap_cfg_getline(line, sizeof(line), parms->config_file)) {
        /*XXX: Not sure how robust this is */
        if (strEQ(line, "</Perl>")) {
            break;
        }

        /*XXX: Less than optimal */
        code = apr_pstrcat(p, code, line, "\n", NULL);
    }

    /* Here, we have to replace our current config node for the next pass */
    if (!*current) {
        *current = apr_pcalloc(p, sizeof(**current));
    }

    (*current)->filename = parms->config_file->name;
    (*current)->line_num = line_num;
    (*current)->directive = apr_pstrdup(p, "Perl");
    (*current)->args = code;
    (*current)->data = args;

    return NULL;
}

#define MP_DEFAULT_PERLSECTION_HANDLER "Apache2::PerlSections"
#define MP_DEFAULT_PERLSECTION_PACKAGE "Apache2::ReadConfig"
#define MP_PERLSECTIONS_SAVECONFIG_SV \
    get_sv("Apache2::PerlSections::Save", FALSE)
#define MP_PERLSECTIONS_SERVER_SV \
    get_sv("Apache2::PerlSections::Server", TRUE)

MP_CMD_SRV_DECLARE(perldo)
{
    apr_pool_t *p = parms->pool;
    server_rec *s = parms->server;
    modperl_config_dir_t *dcfg = (modperl_config_dir_t *)mconfig;
    apr_table_t *options;
    modperl_handler_t *handler = NULL;
    const char *pkg_name = NULL;
    ap_directive_t *directive = parms->directive;
    MP_dSCFG(s);
    MP_PERL_CONTEXT_DECLARE;

    if (!(arg && *arg)) {
        return NULL;
    }

    MP_CHECK_SERVER_OR_HTACCESS_CONTEXT;

    /* we must init earlier than normal */
    modperl_run();

    if (modperl_init_vhost(s, p, NULL) != OK) {
        return "init mod_perl vhost failed";
    }

    MP_PERL_CONTEXT_STORE_OVERRIDE(scfg->mip->parent->perl);

    /* data will be set by a <Perl> section */
    if ((options = directive->data)) {
        const char *pkg_namespace;
        const char *pkg_base;
        const char *handler_name;
        const char *line_header;

        if (!(handler_name = apr_table_get(options, "handler"))) {
            handler_name = apr_pstrdup(p, MP_DEFAULT_PERLSECTION_HANDLER);
            apr_table_set(options, "handler", handler_name);
        }

        handler = modperl_handler_new(p, handler_name);

        if (!(pkg_base = apr_table_get(options, "package"))) {
            pkg_base = apr_pstrdup(p, MP_DEFAULT_PERLSECTION_PACKAGE);
        }

        pkg_namespace = modperl_file2package(p, directive->filename);

        pkg_name = apr_psprintf(p, "%s::%s::line_%d",
                                    pkg_base,
                                    pkg_namespace,
                                    directive->line_num);

        apr_table_set(options, "package", pkg_name);

        line_header = apr_psprintf(p, "\n#line %d %s\n",
                                   directive->line_num,
                                   directive->filename);

        /* put the code about to be executed in the configured package */
        arg = apr_pstrcat(p, "package ", pkg_name, ";", line_header,
                          arg, NULL);
    }

    {
        SV *server = MP_PERLSECTIONS_SERVER_SV;
        SV *code = newSVpv(arg, 0);
        GV *gv = gv_fetchpv("0", TRUE, SVt_PV);
        ENTER;SAVETMPS;
        save_scalar(gv); /* local $0 */
#if MP_PERL_VERSION_AT_LEAST(5, 9, 0)
        TAINT_NOT; /* XXX: temp workaround, see my p5p post */
#endif
        sv_setref_pv(server, "Apache2::ServerRec", (void*)s);
        sv_setpv_mg(GvSV(gv), directive->filename);
        eval_sv(code, G_SCALAR|G_KEEPERR);
        SvREFCNT_dec(code);
        modperl_env_sync_srv_env_hash2table(aTHX_ p, scfg);
        modperl_env_sync_dir_env_hash2table(aTHX_ p, dcfg);
        FREETMPS;LEAVE;
    }

    if (SvTRUE(ERRSV)) {
        MP_PERL_CONTEXT_RESTORE;
        return SvPVX(ERRSV);
    }

    if (handler) {
        int status;
        SV *saveconfig = MP_PERLSECTIONS_SAVECONFIG_SV;
        AV *args = (AV *)NULL;

        modperl_handler_make_args(aTHX_ &args,
                                  "Apache2::CmdParms", parms,
                                  "APR::Table", options,
                                  NULL);

        status = modperl_callback(aTHX_ handler, p, NULL, s, args);

        SvREFCNT_dec((SV*)args);

        if (!(saveconfig && SvTRUE(saveconfig))) {
            modperl_package_unload(aTHX_ pkg_name);
        }

        if (status != OK) {
            char *error = SvTRUE(ERRSV) ? SvPVX(ERRSV) :
                apr_psprintf(p, "<Perl> handler %s failed with status=%d",
                             handler->name, status);
            MP_PERL_CONTEXT_RESTORE;
            return error;
        }
    }

    MP_PERL_CONTEXT_RESTORE;
    return NULL;
}

#define MP_POD_FORMAT(s) \
   (ap_strstr_c(s, "httpd") || ap_strstr_c(s, "apache"))

MP_CMD_SRV_DECLARE(pod)
{
    char line[MAX_STRING_LEN];

    if (arg && *arg && !(MP_POD_FORMAT(arg) || strstr("pod", arg))) {
        return "Unknown =back format";
    }

    while (!ap_cfg_getline(line, sizeof(line), parms->config_file)) {
        if (strEQ(line, "=cut")) {
            break;
        }
        if (strnEQ(line, "=over", 5) && MP_POD_FORMAT(line)) {
            break;
        }
    }

    return NULL;
}

MP_CMD_SRV_DECLARE(pod_cut)
{
    return "=cut without =pod";
}

MP_CMD_SRV_DECLARE(END)
{
    char line[MAX_STRING_LEN];

    while (!ap_cfg_getline(line, sizeof(line), parms->config_file)) {
        /* soak up rest of the file */
    }

    return NULL;
}

/*
 * XXX: the name of this directive may or may not stay.
 * need a way to note that a module has config directives.
 * don't want to start mod_perl when we see a non-special PerlModule.
 */
MP_CMD_SRV_DECLARE(load_module)
{
    const char *errmsg;

    MP_TRACE_d(MP_FUNC, "PerlLoadModule %s", arg);

    /* we must init earlier than normal */
    modperl_run();

    if ((errmsg = modperl_cmd_modules(parms, mconfig, arg))) {
        return errmsg;
    }

    return NULL;
}

/* propogate filters insertion ala SetInputFilter */
MP_CMD_SRV_DECLARE(set_input_filter)
{
    MP_dSCFG(parms->server);
    modperl_config_dir_t *dcfg = (modperl_config_dir_t *)mconfig;
    char *filter;

    if (!MpSrvENABLE(scfg)) {
        return apr_pstrcat(parms->pool,
                           "Perl is disabled for server ",
                           parms->server->server_hostname, NULL);
    }
    if (!MpSrvINPUT_FILTER(scfg)) {
        return apr_pstrcat(parms->pool,
                           "PerlSetInputFilter is disabled for server ",
                           parms->server->server_hostname, NULL);
    }

    while (*arg && (filter = ap_getword(parms->pool, &arg, ';'))) {
        modperl_cmd_push_httpd_filter_handlers(
            &(dcfg->handlers_per_dir[MP_INPUT_FILTER_HANDLER]),
            filter, parms->pool);
    }

    return NULL;
}

/* propogate filters insertion ala SetOutputFilter */
MP_CMD_SRV_DECLARE(set_output_filter)
{
    MP_dSCFG(parms->server);
    modperl_config_dir_t *dcfg = (modperl_config_dir_t *)mconfig;
    char *filter;

    if (!MpSrvENABLE(scfg)) {
        return apr_pstrcat(parms->pool,
                           "Perl is disabled for server ",
                           parms->server->server_hostname, NULL);
    }
    if (!MpSrvINPUT_FILTER(scfg)) {
        return apr_pstrcat(parms->pool,
                           "PerlSetOutputFilter is disabled for server ",
                           parms->server->server_hostname, NULL);
    }

    while (*arg && (filter = ap_getword(parms->pool, &arg, ';'))) {
        modperl_cmd_push_httpd_filter_handlers(
            &(dcfg->handlers_per_dir[MP_OUTPUT_FILTER_HANDLER]),
            filter, parms->pool);
    }

    return NULL;
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
    MP_TRACE_d(MP_FUNC, "%s %d", parms->cmd->name, item); \
    return NULL; \
}

MP_CMD_INTERP_POOL_IMP(start);
MP_CMD_INTERP_POOL_IMP(max);
MP_CMD_INTERP_POOL_IMP(max_spare);
MP_CMD_INTERP_POOL_IMP(min_spare);
MP_CMD_INTERP_POOL_IMP(max_requests);

#endif /* USE_ITHREADS */
