/* Copyright 2001-2004 The Apache Software Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
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

#ifdef USE_ITHREADS

/*
 * perl context overriding and restoration is required when
 * PerlOptions +Parent/+Clone is used in vhosts, and perl is used to
 * at the server startup. So that <Perl> sections, PerlLoadModule,
 * PerlModule and PerlRequire are all run using the right perl context
 * and restore to the original context when they are done.
 *
 * As of perl-5.8.3 it's unfortunate that it uses PERL_GET_CONTEXT and
 * doesn't rely on the passed pTHX internally. When and if perl is
 * fixed to always use pTHX if available, this context switching mess
 * can be removed.
 */

#define MP_PERL_DECLARE_CONTEXT \
    PerlInterpreter *orig_perl; \
    pTHX;

/* XXX: .htaccess support cannot use this perl with threaded MPMs */
#define MP_PERL_OVERRIDE_CONTEXT    \
    orig_perl = PERL_GET_CONTEXT;   \
    aTHX = scfg->mip->parent->perl; \
    PERL_SET_CONTEXT(aTHX);

#define MP_PERL_RESTORE_CONTEXT     \
    PERL_SET_CONTEXT(orig_perl);

#else

#define MP_PERL_DECLARE_CONTEXT
#define MP_PERL_OVERRIDE_CONTEXT
#define MP_PERL_RESTORE_CONTEXT

#endif

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
        MP_TRACE_d(MP_FUNC, "created handler stack\n");
    }

    /* XXX parse_handler if Perl is running */

    modperl_handler_array_push(*handlers, h);
    MP_TRACE_d(MP_FUNC, "pushed handler: %s\n", h->name);

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
        MP_TRACE_d(MP_FUNC, "created handler stack\n");
    }

    modperl_handler_array_push(*handlers, h);
    MP_TRACE_d(MP_FUNC, "pushed httpd filter handler: %s\n", h->name);

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
        MP_TRACE_d(MP_FUNC, "created handler stack\n");
    }

    modperl_handler_array_push(*handlers, h);
    MP_TRACE_d(MP_FUNC, "pushed httpd filter handler: %s\n", h->name);

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
    modperl_trace_level_set_apache(parms->server, arg);
    return NULL;
}

static int modperl_vhost_is_running(server_rec *s)
{
#ifdef USE_ITHREADS
    MP_dSCFG(s);
    int is_vhost = (s != modperl_global_get_server_rec());

    if (is_vhost && scfg->mip) {
        return TRUE;
    }
    else {
        return FALSE;
    }
#else
    return modperl_is_running();
#endif
}

MP_CMD_SRV_DECLARE(switches)
{
    server_rec *s = parms->server;
    MP_dSCFG(s);
    if (s->is_virtual
        ? modperl_vhost_is_running(s)
        : modperl_is_running() ) {
        return modperl_cmd_too_late(parms);
    }
    MP_TRACE_d(MP_FUNC, "arg = %s\n", arg);
    modperl_config_srv_argv_push(arg);
    return NULL;
}

MP_CMD_SRV_DECLARE(modules)
{
    MP_dSCFG(parms->server);
    MP_PERL_DECLARE_CONTEXT;

    MP_CHECK_SERVER_OR_HTACCESS_CONTEXT;

    if (modperl_is_running() &&
        modperl_init_vhost(parms->server, parms->pool, NULL) != OK)
    {
        return "init mod_perl vhost failed";
    }

    if (modperl_is_running()) {
        char *error = NULL;

        MP_TRACE_d(MP_FUNC, "load PerlModule %s\n", arg);

        MP_PERL_OVERRIDE_CONTEXT;
        if (!modperl_require_module(aTHX_ arg, FALSE)) {
            error = SvPVX(ERRSV);
        }
        MP_PERL_RESTORE_CONTEXT;

        return error;
    }
    else {
        MP_TRACE_d(MP_FUNC, "push PerlModule %s\n", arg);
        *(const char **)apr_array_push(scfg->PerlModule) = arg;
        return NULL;
    }
}

MP_CMD_SRV_DECLARE(requires)
{
    MP_dSCFG(parms->server);
    MP_PERL_DECLARE_CONTEXT;

    MP_CHECK_SERVER_OR_HTACCESS_CONTEXT;

    if (modperl_is_running() &&
        modperl_init_vhost(parms->server, parms->pool, NULL) != OK)
    {
        return "init mod_perl vhost failed";
    }

    if (modperl_is_running()) {
        char *error = NULL;

        MP_TRACE_d(MP_FUNC, "load PerlRequire %s\n", arg);

        MP_PERL_OVERRIDE_CONTEXT;
        if (!modperl_require_file(aTHX_ arg, FALSE)) {
            error = SvPVX(ERRSV);
        }
        MP_PERL_RESTORE_CONTEXT;

        return error;
    }
    else {
        MP_TRACE_d(MP_FUNC, "push PerlRequire %s\n", arg);
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
    MP_dSCFG(parms->server);
    MP_PERL_DECLARE_CONTEXT;
    apr_pool_t *p = parms->pool;
    apr_finfo_t finfo;

    if (APR_SUCCESS == apr_stat(&finfo, arg, APR_FINFO_TYPE, p)) {
        if (finfo.filetype != APR_NOFILE) {
             modperl_require_file_t *require = apr_pcalloc(p, sizeof(*require));
#ifdef USE_ITHREADS
            if (modperl_is_running()) {
                MP_PERL_OVERRIDE_CONTEXT;
                require->perl = aTHX;
                MP_PERL_RESTORE_CONTEXT;   
            }
#endif
            require->file = arg;

            MP_TRACE_d(MP_FUNC, "push PerlPostConfigRequire for %s\n", arg);

            *(modperl_require_file_t **)
                apr_array_push(scfg->PerlPostConfigRequire) = require;
        }
    }
    else {
        return apr_pstrcat(p, "No such file : ", arg, NULL);   
    }   

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

    MP_TRACE_d(MP_FUNC, "%s DIR: arg1 = %s, arg2 = %s\n",
               parms->cmd->name, arg1, arg2);

    /* make available via Apache->server->dir_config */
    if (!parms->path) {
        MP_dSCFG(parms->server);
        varfunc(scfg->configvars, scfg->setvars, arg1, arg2);

        MP_TRACE_d(MP_FUNC, "%s SRV: arg1 = %s, arg2 = %s\n",
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

#ifdef ENV_IS_CASELESS /* i.e. WIN32 */
    /* we turn off env magic during hv_store later, so do this now,
     * else lookups on keys with lowercase characters will fails
     * because Perl will uppercase them prior to lookup.
     */
    modperl_str_toupper((char *)arg);
#endif

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

#define MP_DEFAULT_PERLSECTION_HANDLER "Apache::PerlSections"
#define MP_DEFAULT_PERLSECTION_PACKAGE "Apache::ReadConfig"
#define MP_PERLSECTIONS_SAVECONFIG_SV \
    get_sv("Apache::PerlSections::Save", FALSE)

MP_CMD_SRV_DECLARE(perldo)
{
    apr_pool_t *p = parms->pool;
    server_rec *s = parms->server;
    apr_table_t *options;
    modperl_handler_t *handler = NULL;
    const char *pkg_name = NULL;
    ap_directive_t *directive = parms->directive;
#ifdef USE_ITHREADS
    MP_dSCFG(s);
    MP_PERL_DECLARE_CONTEXT;
#endif

    if (!(arg && *arg)) {
        return NULL;
    }

    MP_CHECK_SERVER_OR_HTACCESS_CONTEXT;

    /* we must init earlier than normal */
    modperl_run();

    if (modperl_init_vhost(s, p, NULL) != OK) {
        return "init mod_perl vhost failed";
    }

    MP_PERL_OVERRIDE_CONTEXT;

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
        GV *gv = gv_fetchpv("0", TRUE, SVt_PV);
        ENTER;SAVETMPS;
        save_scalar(gv); /* local $0 */
        sv_setpv_mg(GvSV(gv), directive->filename);
        eval_pv(arg, FALSE);
        FREETMPS;LEAVE;
    }

    if (SvTRUE(ERRSV)) {
        MP_PERL_RESTORE_CONTEXT;
        return SvPVX(ERRSV);
    }

    if (handler) {
        int status;
        SV *saveconfig = MP_PERLSECTIONS_SAVECONFIG_SV;
        AV *args = Nullav;

        modperl_handler_make_args(aTHX_ &args,
                                  "Apache::CmdParms", parms,
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
            MP_PERL_RESTORE_CONTEXT;
            return error;
        }
    }

    MP_PERL_RESTORE_CONTEXT;
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

    MP_TRACE_d(MP_FUNC, "PerlLoadModule %s\n", arg);

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
    MP_TRACE_d(MP_FUNC, "%s %d\n", parms->cmd->name, item); \
    return NULL; \
}

MP_CMD_INTERP_POOL_IMP(start);
MP_CMD_INTERP_POOL_IMP(max);
MP_CMD_INTERP_POOL_IMP(max_spare);
MP_CMD_INTERP_POOL_IMP(min_spare);
MP_CMD_INTERP_POOL_IMP(max_requests);

#endif /* USE_ITHREADS */
