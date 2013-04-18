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

/* make sure that mod_perl won't try to start itself, while it's
 * already starting. If the flag's value is 1 * it's still starting,
 * when it's 2 it is running */
static int MP_init_status = 0;

#define MP_IS_NOT_RUNNING (MP_init_status == 0 ? 1 : 0)
#define MP_IS_STARTING    (MP_init_status == 1 ? 1 : 0)
#define MP_IS_RUNNING     (MP_init_status == 2 ? 1 : 0)

/* false while there is only the parent process and may be child
 * processes, but no threads around, useful for allowing things that
 * don't require locking and won't affect other threads. It should
 * become true just before the child_init phase  */
static int MP_threads_started = 0;

int modperl_threads_started(void)
{
    return MP_threads_started;
}

static int MP_threaded_mpm = 0;

int modperl_threaded_mpm(void)
{
    return MP_threaded_mpm;
}

/* sometimes non-threaded mpm also needs to know whether it's still
 * starting up or after post_config) */
static int MP_post_post_config_phase = 0;

int modperl_post_post_config_phase(void)
{
    return MP_post_post_config_phase;
}

#ifndef USE_ITHREADS
static apr_status_t modperl_shutdown(void *data)
{
    modperl_cleanup_data_t *cdata = (modperl_cleanup_data_t *)data;
    PerlInterpreter *perl = (PerlInterpreter *)cdata->data;
    void **handles;

    handles = modperl_xs_dl_handles_get(aTHX);

    MP_TRACE_i(MP_FUNC, "destroying interpreter=0x%lx",
               (unsigned long)perl);

    modperl_perl_destruct(perl);

    modperl_xs_dl_handles_close(handles);

    return APR_SUCCESS;
}
#endif

static const char *MP_xs_loaders[] = {
    "Apache2", "APR", NULL,
};

#define MP_xs_loader_name "%s::XSLoader::BOOTSTRAP"

/* ugly hack to have access to startup pool and server during xs_init */
static struct {
    apr_pool_t *p;
    server_rec *s;
} MP_boot_data = {NULL,NULL};

#define MP_boot_data_set(pool, server) \
    MP_boot_data.p = pool; \
    MP_boot_data.s = server

#define MP_dBOOT_DATA \
    apr_pool_t *p = MP_boot_data.p; \
    server_rec *s = MP_boot_data.s

static void modperl_boot(pTHX_ void *data)
{
    MP_dBOOT_DATA;
    int i;

    modperl_env_clear(aTHX);

    modperl_env_default_populate(aTHX);

    modperl_env_configure_server(aTHX_ p, s);

    modperl_perl_core_global_init(aTHX);

    for (i=0; MP_xs_loaders[i]; i++) {
        char *name = Perl_form(aTHX_ MP_xs_loader_name, MP_xs_loaders[i]);
        newCONSTSUB(PL_defstash, name, newSViv(1));
    }

    /* outside mod_perl this is done by ModPerl::Const.xs */
    newXS("ModPerl::Const::compile", XS_modperl_const_compile, __FILE__);

    /* make sure DynaLoader is loaded before XSLoader
     * - to workaround bug in 5.6.1 that can trigger a segv
     * when using modperl as a dso
     * - also needed when <Perl> sections are loaded from +Parent vhost
     */
    modperl_require_module(aTHX_ "DynaLoader", FALSE);

    IoFLUSH_on(PL_stderrgv); /* unbuffer STDERR */
}

static void modperl_xs_init(pTHX)
{
    xs_init(aTHX); /* see modperl_xsinit.c */

    /* XXX: in 5.7.2+ we can call the body of modperl_boot here
     * but in 5.6.1 the Perl runtime is not properly setup yet
     * so we have to pull this stunt to delay
     */
    SAVEDESTRUCTOR_X(modperl_boot, 0);
}

/*
 * the "server_pool" is a subpool of the parent pool (aka "pconf")
 * this is where we register the cleanups that teardown the interpreter.
 * the parent process will run the cleanups since server_pool is a subpool
 * of pconf.  we manually clear the server_pool to run cleanups in the
 * child processes
 *
 * the "server_user_pool" is a subpool of the "server_pool", this is
 * the pool which is exposed to users, so that they can register
 * cleanup callbacks. This is needed so that the perl cleanups won't
 * be run before user cleanups are executed.
 *
 */
static apr_pool_t *server_pool = NULL;
static apr_pool_t *server_user_pool = NULL;

apr_pool_t *modperl_server_pool(void)
{
    return server_pool;
}

apr_pool_t *modperl_server_user_pool(void)
{
    return server_user_pool;
}

static void set_taint_var(PerlInterpreter *perl)
{
    dTHXa(perl);

/* 5.7.3+ has a built-in special ${^TAINT}, backport it to 5.6.0+ */
#if MP_PERL_VERSION_AT_MOST(5, 7, 2)
    {
        GV *gv = gv_fetchpv("\024AINT", GV_ADDMULTI, SVt_IV);
        sv_setiv(GvSV(gv), PL_tainting);
        SvREADONLY_on(GvSV(gv));
    }
#endif /* perl v < 5.7.3 */

#ifdef MP_COMPAT_1X
    {
        GV *gv = gv_fetchpv("Apache2::__T", GV_ADDMULTI, SVt_PV);
        sv_setiv(GvSV(gv), PL_tainting);
        SvREADONLY_on(GvSV(gv));
    }
#endif /* MP_COMPAT_1X */

}

PerlInterpreter *modperl_startup(server_rec *s, apr_pool_t *p)
{
    AV *endav;
    dTHXa(NULL);
    MP_dSCFG(s);
    PerlInterpreter *perl;
    int status;
    char **argv;
    int argc;
#ifndef USE_ITHREADS
    modperl_cleanup_data_t *cdata;
#endif

    /* ensure that we start the base server's perl, before vhost's
     * one, if modperl_startup was called by vhost before the former
     * was started */
    if (MP_init_status != 2) {
        server_rec *base_server = modperl_global_get_server_rec();
        PerlInterpreter *base_perl;

        MP_init_status = 2; /* calls itself, so set the flag early */
        base_perl = modperl_startup(base_server, p);

        if (base_server == s ) {
            return base_perl;
        }
    }

#ifdef MP_TRACE
    {
        server_rec *base_server = modperl_global_get_server_rec();
        const char *desc = modperl_server_desc(s, p);
        if (base_server == s) {
            MP_TRACE_i(MP_FUNC,
                       "starting the parent perl for the base server", desc);
        }
        else {
            MP_TRACE_i(MP_FUNC,
                       "starting the parent perl for vhost %s", desc);
        }
    }
#endif

#ifdef MP_USE_GTOP
    MP_TRACE_m_do(
        modperl_gtop_do_proc_mem_before(MP_FUNC, "perl_parse");
    );
#endif

    argv = modperl_config_srv_argv_init(scfg, &argc);

    if (!(perl = perl_alloc())) {
        perror("perl_alloc");
        exit(1);
    }

#ifdef USE_ITHREADS
    aTHX = perl;
#endif

    perl_construct(perl);

    modperl_hash_seed_set(aTHX);

    modperl_io_apache_init(aTHX);

    PL_perl_destruct_level = 2;

    MP_boot_data_set(p, s);
    status = perl_parse(perl, modperl_xs_init, argc, argv, NULL);
    MP_boot_data_set(NULL, NULL);

    if (status) {
        perror("perl_parse");
        exit(1);
    }

    /* suspend END blocks to be run at server shutdown */
    endav = PL_endav;
    PL_endav = (AV *)NULL;

/* This was fixed in 5.9.0/5.8.1 (17775), but won't compile after 19122 */
#if MP_PERL_VERSION(5, 8, 0) && \
    defined(USE_REENTRANT_API) && defined(HAS_CRYPT_R) && defined(__GLIBC__)
    /* workaround perl5.8.0/glibc bug */
    PL_reentrant_buffer->_crypt_struct.current_saltbits = 0;
#endif

    /* We need to reset $0 to argv[0] (httpd) since perl_parse() will
     * have set it to '-e'. Being magic-aware ensures that some
     * OS-specific magic will happen (i.e. setproctitle() on *BSDs)
     */
    PL_origalen = strlen(argv[0]) + 1;
    sv_setpv_mg(get_sv("0",0), argv[0]);

    perl_run(perl);

#ifdef USE_ITHREADS
    /* base server / virtual host w/ +Parent gets its own mip */
    modperl_interp_init(s, p, perl);

    /* mark the parent perl to be destroyed */
    MpInterpBASE_On(scfg->mip->parent);
#endif

    PL_endav = endav;

    set_taint_var(perl);

    MP_TRACE_i(MP_FUNC, "constructed interpreter=0x%lx",
               (unsigned long)perl);

#ifdef MP_USE_GTOP
    MP_TRACE_m_do(
        modperl_gtop_do_proc_mem_after(MP_FUNC, "perl_parse");
    );
#endif

#ifdef MP_COMPAT_1X
    {
        char *path, *path1;
        apr_finfo_t finfo;
        /* 1) push @INC, $ServerRoot */
        av_push(GvAV(PL_incgv), newSVpv(ap_server_root, 0));

        /* 2) push @INC, $ServerRoot/lib/perl only if it exists */
        apr_filepath_merge(&path, ap_server_root, "lib",
                           APR_FILEPATH_NATIVE, p);
        apr_filepath_merge(&path1, path, "perl",
                           APR_FILEPATH_NATIVE, p);
        if (APR_SUCCESS == apr_stat(&finfo, path1, APR_FINFO_TYPE, p)) {
            if (finfo.filetype == APR_DIR) {
                av_push(GvAV(PL_incgv), newSVpv(path1, 0));
            }
        }
    }
#endif /* MP_COMPAT_1X */

    /* base perl and each vhost +Parent should have this init'ed */
    modperl_handler_anon_init(aTHX_ p);

    if (!modperl_config_apply_PerlRequire(s, scfg, perl, p)) {
        exit(1);
    }

    if (!modperl_config_apply_PerlModule(s, scfg, perl, p)) {
        exit(1);
    }

#ifndef USE_ITHREADS
    cdata = modperl_cleanup_data_new(server_pool, (void*)perl);
    apr_pool_cleanup_register(server_pool, cdata,
                              modperl_shutdown, apr_pool_cleanup_null);
#endif

    return perl;
}

int modperl_init_vhost(server_rec *s, apr_pool_t *p,
                       server_rec *base_server)
{
    MP_dSCFG(s);
    modperl_config_srv_t *base_scfg;
    PerlInterpreter *base_perl;
    PerlInterpreter *perl;
    const char *vhost = modperl_server_desc(s, p);

    if (!scfg) {
        MP_TRACE_i(MP_FUNC, "server %s has no mod_perl config", vhost);
        return OK;
    }

    if (base_server == NULL) {
        base_server = modperl_global_get_server_rec();
    }

    MP_TRACE_i(MP_FUNC, "Init vhost %s: s=0x%lx, base_s=0x%lx",
               vhost, s, base_server);

    if (base_server == s) {
        MP_TRACE_i(MP_FUNC, "base server is not vhost, skipping %s",
                   vhost);
        return OK;
    }

    base_scfg = modperl_config_srv_get(base_server);

#ifdef USE_ITHREADS
    perl = base_perl = base_scfg->mip->parent->perl;
#else
    perl = base_perl = base_scfg->perl;
#endif /* USE_ITHREADS */

#ifdef USE_ITHREADS

    if (scfg->mip) {
        MP_TRACE_i(MP_FUNC, "server %s already initialized", vhost);
        return OK;
    }

    /* the base server could have mod_perl callbacks disabled, but it
     * still needs perl to drive the vhosts */
    if (!MpSrvENABLE(scfg) && s->is_virtual) {
        MP_TRACE_i(MP_FUNC, "mod_perl disabled for server %s", vhost);
        scfg->mip = NULL;
        return OK;
    }

    PERL_SET_CONTEXT(perl);

#endif /* USE_ITHREADS */

    MP_TRACE_d_do(MpSrv_dump_flags(scfg, s->server_hostname));

    /* if alloc flags is On, virtual host gets its own parent perl */
    if (MpSrvPARENT(scfg)) {
        perl = modperl_startup(s, p);
        MP_TRACE_i(MP_FUNC,
                   "created parent interpreter for VirtualHost %s",
                   modperl_server_desc(s, p));
    }
    else {
#ifdef USE_ITHREADS
        /* virtual host w/ +Clone gets its own mip */
        if (MpSrvCLONE(scfg)) {
            modperl_interp_init(s, p, perl);
        }
#endif

        if (!modperl_config_apply_PerlRequire(s, scfg, perl, p)) {
            return HTTP_INTERNAL_SERVER_ERROR;
        }

        if (!modperl_config_apply_PerlModule(s, scfg, perl, p)) {
            return HTTP_INTERNAL_SERVER_ERROR;
        }
    }

#ifdef USE_ITHREADS
    if (!scfg->mip) {
        /* since mips are created after merge_server_configs()
         * need to point to the base mip here if this vhost
         * doesn't have its own
         */
        MP_TRACE_i(MP_FUNC, "%s mip inherited from %s",
                   vhost, modperl_server_desc(base_server, p));
        scfg->mip = base_scfg->mip;
    }
#endif  /* USE_ITHREADS */

    return OK;
}

void modperl_init(server_rec *base_server, apr_pool_t *p)
{
    server_rec *s;
    PerlInterpreter *base_perl;
#ifdef MP_TRACE
    modperl_config_srv_t *base_scfg = modperl_config_srv_get(base_server);

    MP_TRACE_d_do(MpSrv_dump_flags(base_scfg,
                                   base_server->server_hostname));
#endif /* MP_TRACE */

#ifndef USE_ITHREADS
    if (modperl_threaded_mpm()) {
        ap_log_error(APLOG_MARK, APLOG_ERR, 0, base_server,
                     "cannot use threaded MPM without ithreads enabled Perl");
        exit(1);
    }
#endif

    base_perl = modperl_startup(base_server, p);

    for (s=base_server->next; s; s=s->next) {
        if (modperl_init_vhost(s, p, base_server) != OK) {
            exit(1); /*XXX*/
        }
    }

#ifdef USE_ITHREADS
    /* after other parent perls were started in vhosts, make sure that
     * the context is set to the base_perl */
    PERL_SET_CONTEXT(base_perl);
#endif

}

static int modperl_post_config_require(server_rec *s, apr_pool_t *p)
{
    for (; s; s=s->next) {
        MP_dSCFG(s);
        if (!modperl_config_apply_PerlPostConfigRequire(s, scfg, p)) {
            return FALSE;
        }
    }
    return TRUE;
}

#ifdef USE_ITHREADS
static void modperl_init_clones(server_rec *s, apr_pool_t *p)
{
#ifdef MP_TRACE
    modperl_config_srv_t *base_scfg = modperl_config_srv_get(s);
    char *base_name = modperl_server_desc(s, p);
#endif /* MP_TRACE */

    if (!modperl_threaded_mpm()) {
        MP_TRACE_i(MP_FUNC, "no clones created for non-threaded mpm");
        return;
    }

    for (; s; s=s->next) {
        MP_dSCFG(s);
#ifdef MP_TRACE
        char *name = modperl_server_desc(s, p);

        MP_TRACE_i(MP_FUNC, "PerlInterpScope set to %s for %s",
                   modperl_interp_scope_desc(scfg->interp_scope), name);
#else
        char *name = NULL;
#endif /* MP_TRACE */

        if (scfg->mip->tipool->idle) {
#ifdef MP_TRACE
            if (scfg->mip == base_scfg->mip) {
                MP_TRACE_i(MP_FUNC,
                           "%s interp pool inherited from %s",
                           name, base_name);
            }
            else {
                MP_TRACE_i(MP_FUNC,
                           "%s interp pool already initialized",
                           name);
            }
#endif /* MP_TRACE */
        }
        else {
            MP_TRACE_i(MP_FUNC, "initializing interp pool for %s",
                       name);
            modperl_tipool_init(scfg->mip->tipool);
        }
    }
}
#endif /* USE_ITHREADS */

void modperl_init_globals(server_rec *s, apr_pool_t *pconf)
{
    ap_mpm_query(AP_MPMQ_IS_THREADED, &MP_threaded_mpm);

    MP_TRACE_g(MP_FUNC, "mod_perl globals are configured");

    modperl_global_init_pconf(pconf, pconf);
    modperl_global_init_server_rec(pconf, s);

    modperl_tls_create_request_rec(pconf);

    /* init the counter to 0 */
    modperl_global_anon_cnt_init(pconf);
}

/*
 * modperl_sys_{init,term} are things that happen
 * once per-parent process, not per-interpreter
 */
static apr_status_t modperl_sys_init(void)
{
    int argc = 0;
    char **argv = NULL, **env = NULL;

    MP_TRACE_i(MP_FUNC, "mod_perl sys init");

    /* not every OS uses those vars in PERL_SYS_INIT3 macro */
    argc = argc; argv = argv; env = env;

    PERL_SYS_INIT3(&argc, &argv, &env);

#if 0 /*XXX*/
#ifdef PTHREAD_ATFORK
    if (!ap_exists_config_define("PERL_PTHREAD_ATFORK_DONE")) {
        PTHREAD_ATFORK(Perl_atfork_lock,
                       Perl_atfork_unlock,
                       Perl_atfork_unlock);
        *(char **)apr_array_push(ap_server_config_defines) =
            "PERL_PTHREAD_ATFORK_DONE";
    }
#endif
#endif

    /* modifies PL_ppaddr */
    modperl_perl_pp_set_all();

    /* modifies PL_vtbl_env{elem} */
    modperl_env_init();

    return APR_SUCCESS;
}

static apr_status_t modperl_sys_term(void *data)
{
    /* PERL_SYS_TERM() needs 'my_perl' as of 5.9.5 */
#if MP_PERL_VERSION_AT_LEAST(5, 9, 5) && defined(USE_ITHREADS)
    modperl_cleanup_data_t *cdata = (modperl_cleanup_data_t *)data;
    PERL_UNUSED_DECL PerlInterpreter *my_perl = cdata == NULL ? NULL : (PerlInterpreter *)cdata->data;
#endif
    MP_init_status = 0;
    MP_threads_started = 0;
    MP_post_post_config_phase = 0;

    MP_PERL_FREE_THREAD_KEY_WORKAROUND;

    MP_TRACE_i(MP_FUNC, "mod_perl sys term");

    modperl_env_unload();

    modperl_perl_pp_unset_all();

    PERL_SYS_TERM();

    return APR_SUCCESS;
}

int modperl_hook_init(apr_pool_t *pconf, apr_pool_t *plog,
                      apr_pool_t *ptemp, server_rec *s)
{
    if (MP_IS_STARTING || MP_IS_RUNNING) {
        return OK;
    }

    MP_TRACE_i(MP_FUNC, "mod_perl hook init");

    MP_init_status = 1; /* now starting */

    modperl_restart_count_inc(s);

    apr_pool_create(&server_pool, pconf);
    apr_pool_tag(server_pool, "mod_perl server pool");

    apr_pool_create(&server_user_pool, pconf);
    apr_pool_tag(server_user_pool, "mod_perl server user pool");

    modperl_sys_init();
    apr_pool_cleanup_register(server_pool, NULL,
                              modperl_sys_term, apr_pool_cleanup_null);

    modperl_init(s, pconf);

    return OK;
}

/*
 * if we need to init earlier than post_config,
 * e.g. <Perl> sections or directive handlers.
 */
int modperl_run(void)
{
    return modperl_hook_init(modperl_global_get_pconf(),
                             NULL,
                             NULL,
                             modperl_global_get_server_rec());
}

int modperl_is_running(void)
{
    return MP_IS_RUNNING;
}

int modperl_hook_pre_config(apr_pool_t *p, apr_pool_t *plog,
                            apr_pool_t *ptemp)
{
    /* we can't have PerlPreConfigHandler without first configuring mod_perl */

    /* perl 5.8.1+ */
    modperl_hash_seed_init(p);

    return OK;
}

static int modperl_hook_pre_connection(conn_rec *c, void *csd)
{
    modperl_input_filter_add_connection(c);
    modperl_output_filter_add_connection(c);
    return OK;
}

static int modperl_hook_post_config_last(apr_pool_t *pconf, apr_pool_t *plog,
                                         apr_pool_t *ptemp, server_rec *s)
{
    /* in the threaded environment, no server_rec/process_rec
     * modifications should be done beyond this point */
#ifdef USE_ITHREADS
    MP_dSCFG(s);
    dTHXa(scfg->mip->parent->perl);
#endif

    if (!modperl_post_config_require(s, pconf)) {
        exit(1);
    }

    if (modperl_threaded_mpm()) {
        MP_threads_started = 1;
    }

    MP_post_post_config_phase = 1;

#ifdef MP_TRACE
    /* httpd core open_logs handler re-opens s->error_log, which might
     * change, even though it still points to the same physical file
     * (.e.g on win32 the filehandle will be different. Therefore
     * reset the tracing logfile setting here, since this is the
     * earliest place, happening after the open_logs phase.
     *
     * Moreover, we need to dup the filehandle so that when the server
     * shuts down, we will be able to log to error_log after Apache
     * has closed it (which happens too early for our likening).
     */
    {
        apr_file_t *dup;
        MP_RUN_CROAK(apr_file_dup(&dup, s->error_log, pconf),
                     "mod_perl core post_config");
        modperl_trace_logfile_set(dup);
    }
#endif

#if MP_PERL_VERSION_AT_LEAST(5, 9, 0)
#define MP_PERL_VERSION_STAMP "Perl/%" SVf
#else
#define MP_PERL_VERSION_STAMP "Perl/v%vd"
#endif

    ap_add_version_component(pconf, MP_VERSION_STRING);
    ap_add_version_component(pconf,
                             Perl_form(aTHX_ MP_PERL_VERSION_STAMP,
                                       PL_patchlevel));

    modperl_mgv_hash_handlers(pconf, s);
    modperl_modglobal_hash_keys(aTHX);
    modperl_env_hash_keys(aTHX);
#ifdef USE_ITHREADS
    modperl_init_clones(s, pconf);
#endif

#ifdef MP_NEED_HASH_SEED_FIXUP
    ap_log_error(APLOG_MARK, APLOG_INFO, 0, s,
                 "mod_perl: using Perl HASH_SEED: %"UVuf, MP_init_hash_seed);
#endif

    return OK;
}

static int modperl_hook_create_request(request_rec *r)
{
    MP_dRCFG;

    modperl_config_req_init(r, rcfg);

    /* set the default for cgi header parsing On as early as possible
     * so $r->content_type in any phase after header_parser could turn
     * it off. wb->header_parse will be set to 1 only if this flag
     * wasn't turned off and MpDirPARSE_HEADERS is on
     */
    MpReqPARSE_HEADERS_On(rcfg);

    return OK;
}

static int modperl_hook_post_read_request(request_rec *r)
{
    /* if 'PerlOptions +GlobalRequest' is outside a container */
    modperl_global_request_cfg_set(r);

    return OK;
}

static int modperl_hook_header_parser(request_rec *r)
{
    /* if 'PerlOptions +GlobalRequest' is inside a container */
    modperl_global_request_cfg_set(r);

    return OK;
}

static int modperl_destruct_level = 2; /* default is full tear down */

int modperl_perl_destruct_level(void)
{
    return modperl_destruct_level;
}

#ifdef USE_ITHREADS

static apr_status_t
modperl_perl_call_endav_mip(pTHX_ modperl_interp_pool_t *mip,
                            void *data)
{
    modperl_perl_call_endav(aTHX);
    return APR_SUCCESS;
}

#endif /* USE_ITHREADS */

static apr_status_t modperl_child_exit(void *data)
{
    char *level = NULL;
    server_rec *s = (server_rec *)data;

    modperl_callback_process(MP_CHILD_EXIT_HANDLER, server_pool, s,
                             MP_HOOK_VOID);

    if ((level = getenv("PERL_DESTRUCT_LEVEL"))) {
        modperl_destruct_level = atoi(level);
    }
    else {
        /* default to no teardown in the children */
        modperl_destruct_level = 0;
    }

    if (modperl_destruct_level) {
        apr_pool_clear(server_pool);
    }
    else {
        /* run the END blocks of this child process if
         * modperl_perl_destruct is not called for this process */
#ifdef USE_ITHREADS
        modperl_interp_mip_walk_servers(NULL, s,
                                        modperl_perl_call_endav_mip,
                                        (void*)NULL);
#else
        modperl_perl_call_endav(aTHX);
#endif
    }

    server_pool = NULL;

    return APR_SUCCESS;
}

static void modperl_hook_child_init(apr_pool_t *p, server_rec *s)
{
    modperl_perl_init_ids_server(s);

    apr_pool_cleanup_register(p, (void *)s, modperl_child_exit,
                              apr_pool_cleanup_null);
}

#define MP_FILTER_HANDLER(f) f, NULL

void modperl_register_hooks(apr_pool_t *p)
{

#ifdef USE_ITHREADS
    APR_REGISTER_OPTIONAL_FN(modperl_interp_unselect);
    APR_REGISTER_OPTIONAL_FN(modperl_thx_interp_get);
#endif

    /* for <IfDefine MODPERL2> and Apache2->define("MODPERL2") */
    *(char **)apr_array_push(ap_server_config_defines) =
        apr_pstrdup(p, "MODPERL2");

    ap_hook_pre_config(modperl_hook_pre_config,
                       NULL, NULL, APR_HOOK_MIDDLE);

    ap_hook_open_logs(modperl_hook_init,
                      NULL, NULL, APR_HOOK_FIRST);

    ap_hook_post_config(modperl_hook_post_config_last,
                        NULL, NULL, APR_HOOK_REALLY_LAST);

    ap_hook_handler(modperl_response_handler,
                    NULL, NULL, APR_HOOK_MIDDLE);

    ap_hook_handler(modperl_response_handler_cgi,
                    NULL, NULL, APR_HOOK_MIDDLE);

    ap_hook_insert_filter(modperl_output_filter_add_request,
                          NULL, NULL, APR_HOOK_LAST);

    ap_hook_insert_filter(modperl_input_filter_add_request,
                          NULL, NULL, APR_HOOK_LAST);

    ap_register_output_filter(MP_FILTER_REQUEST_OUTPUT_NAME,
                              MP_FILTER_HANDLER(modperl_output_filter_handler),
                              AP_FTYPE_RESOURCE);

    ap_register_input_filter(MP_FILTER_REQUEST_INPUT_NAME,
                             MP_FILTER_HANDLER(modperl_input_filter_handler),
                             AP_FTYPE_RESOURCE);

    ap_register_output_filter(MP_FILTER_CONNECTION_OUTPUT_NAME,
                              MP_FILTER_HANDLER(modperl_output_filter_handler),
                              AP_FTYPE_CONNECTION);

    ap_register_input_filter(MP_FILTER_CONNECTION_INPUT_NAME,
                             MP_FILTER_HANDLER(modperl_input_filter_handler),
                             AP_FTYPE_CONNECTION);

    ap_hook_pre_connection(modperl_hook_pre_connection,
                           NULL, NULL, APR_HOOK_FIRST);

    ap_hook_create_request(modperl_hook_create_request,
                           NULL, NULL, APR_HOOK_MIDDLE);

    /* both of these hooks need to run really, really first.
     * otherwise, the global request_rec will be set up _after_ some
     * Perl handlers run.
     */
    ap_hook_post_read_request(modperl_hook_post_read_request,
                              NULL, NULL, MODPERL_HOOK_REALLY_REALLY_FIRST);

    ap_hook_header_parser(modperl_hook_header_parser,
                          NULL, NULL, MODPERL_HOOK_REALLY_REALLY_FIRST);

    ap_hook_child_init(modperl_hook_child_init,
                       NULL, NULL, MODPERL_HOOK_REALLY_REALLY_FIRST);

    modperl_register_handler_hooks();
}

static const command_rec modperl_cmds[] = {
    MP_CMD_SRV_ITERATE("PerlSwitches", switches, "Perl Switches"),
    MP_CMD_DIR_ITERATE("PerlModule", modules, "PerlModule"),
    MP_CMD_DIR_ITERATE("PerlRequire", requires, "PerlRequire"),
    MP_CMD_SRV_ITERATE("PerlConfigRequire", config_requires, "PerlConfigRequire"),
    MP_CMD_SRV_ITERATE("PerlPostConfigRequire", post_config_requires, "PerlPostConfigRequire"),
    MP_CMD_DIR_ITERATE("PerlOptions", options, "Perl Options"),
    MP_CMD_DIR_ITERATE("PerlInitHandler", init_handlers, "Subroutine name"),
    MP_CMD_DIR_TAKE2("PerlSetVar", set_var, "PerlSetVar"),
    MP_CMD_DIR_ITERATE2("PerlAddVar", add_var, "PerlAddVar"),
    MP_CMD_DIR_TAKE2("PerlSetEnv", set_env, "PerlSetEnv"),
    MP_CMD_SRV_TAKE1("PerlPassEnv", pass_env, "PerlPassEnv"),
    MP_CMD_DIR_RAW_ARGS_ON_READ("<Perl", perl, "Perl Code"),
    MP_CMD_DIR_RAW_ARGS("Perl", perldo, "Perl Code"),

    MP_CMD_DIR_TAKE1("PerlSetInputFilter", set_input_filter,
                     "filter[;filter]"),
    MP_CMD_DIR_TAKE1("PerlSetOutputFilter", set_output_filter,
                     "filter[;filter]"),

    MP_CMD_DIR_RAW_ARGS_ON_READ("=pod", pod, "Start of POD"),
    MP_CMD_DIR_RAW_ARGS_ON_READ("=back", pod, "End of =over"),
    MP_CMD_DIR_RAW_ARGS_ON_READ("=cut", pod_cut, "End of POD"),
    MP_CMD_DIR_RAW_ARGS_ON_READ("__END__", END, "Stop reading config"),

    MP_CMD_SRV_RAW_ARGS("PerlLoadModule", load_module, "A Perl module"),
#ifdef MP_TRACE
    MP_CMD_SRV_TAKE1("PerlTrace", trace, "Trace level"),
#endif
#ifdef USE_ITHREADS
    MP_CMD_SRV_TAKE1("PerlInterpStart", interp_start,
                     "Number of Perl interpreters to start"),
    MP_CMD_SRV_TAKE1("PerlInterpMax", interp_max,
                     "Max number of running Perl interpreters"),
    MP_CMD_SRV_TAKE1("PerlInterpMaxSpare", interp_max_spare,
                     "Max number of spare Perl interpreters"),
    MP_CMD_SRV_TAKE1("PerlInterpMinSpare", interp_min_spare,
                     "Min number of spare Perl interpreters"),
    MP_CMD_SRV_TAKE1("PerlInterpMaxRequests", interp_max_requests,
                     "Max number of requests per Perl interpreters"),
    MP_CMD_DIR_TAKE1("PerlInterpScope", interp_scope,
                     "Scope of a Perl interpreter"),
#endif
#ifdef MP_COMPAT_1X
    MP_CMD_DIR_FLAG("PerlSendHeader", send_header,
                    "Tell mod_perl to scan output for HTTP headers"),
    MP_CMD_DIR_FLAG("PerlSetupEnv", setup_env,
                    "Turn setup of %ENV On or Off"),
    MP_CMD_DIR_ITERATE("PerlHandler", response_handlers,
                       "Subroutine name"),
    MP_CMD_SRV_FLAG("PerlTaintCheck", taint_check,
                    "Turn on -T switch"),
    MP_CMD_SRV_FLAG("PerlWarn", warn,
                    "Turn on -w switch"),
#endif
    MP_CMD_ENTRIES,
    { NULL },
};

void modperl_response_init(request_rec *r)
{
    MP_dRCFG;
    MP_dDCFG;
    modperl_wbucket_t *wb;

    if (!rcfg->wbucket) {
        rcfg->wbucket =
            (modperl_wbucket_t *)apr_palloc(r->pool,
                                            sizeof(*rcfg->wbucket));
    }

    wb = rcfg->wbucket;

    /* setup buffer for output */
    wb->pool = r->pool;
    wb->filters = &r->output_filters;
    wb->outcnt = 0;
    wb->header_parse = MpDirPARSE_HEADERS(dcfg) && MpReqPARSE_HEADERS(rcfg)
        ? 1 : 0;
    wb->r = r;
}

apr_status_t modperl_response_finish(request_rec *r)
{
    MP_dRCFG;

    /* flush output buffer */
    return modperl_wbucket_flush(rcfg->wbucket, FALSE);
}

static int modperl_response_handler_run(request_rec *r)
{
    int retval;

    modperl_response_init(r);

    retval = modperl_callback_per_dir(MP_RESPONSE_HANDLER, r, MP_HOOK_RUN_FIRST);

    if ((retval == DECLINED) && r->content_type) {
        r->handler = r->content_type; /* let http_core or whatever try */
    }

    return retval;
}

int modperl_response_handler(request_rec *r)
{
    MP_dDCFG;
#ifdef USE_ITHREADS
    MP_dRCFG;
#endif
    apr_status_t retval, rc;

#ifdef USE_ITHREADS
    pTHX;
    modperl_interp_t *interp;
#endif

    if (!strEQ(r->handler, "modperl")) {
        return DECLINED;
    }

#ifdef USE_ITHREADS
    interp = modperl_interp_select(r, r->connection, r->server);
    aTHX = interp->perl;
    if (MpInterpPUTBACK(interp)) {
        rcfg->interp = interp;
    }
#endif

    /* default is -SetupEnv, add if PerlOption +SetupEnv */
    if (MpDirSETUP_ENV(dcfg)) {
        modperl_env_request_populate(aTHX_ r);
    }

    retval = modperl_response_handler_run(r);
    rc = modperl_response_finish(r);
    if (rc != APR_SUCCESS) {
        retval = rc;
    }

#ifdef USE_ITHREADS
    if (MpInterpPUTBACK(interp)) {
        /* PerlInterpScope handler */
        rcfg->interp = NULL;
        modperl_interp_unselect(interp);
    }
#endif

    return retval;
}

int modperl_response_handler_cgi(request_rec *r)
{
    MP_dDCFG;
    GV *h_stdin, *h_stdout;
    apr_status_t retval, rc;
    MP_dRCFG;
#ifdef USE_ITHREADS
    pTHX;
    modperl_interp_t *interp;
#endif

    if (!strEQ(r->handler, "perl-script")) {
        return DECLINED;
    }

#ifdef USE_ITHREADS
    interp = modperl_interp_select(r, r->connection, r->server);
    aTHX = interp->perl;
    if (MpInterpPUTBACK(interp)) {
        rcfg->interp = interp;
    }
#endif

    modperl_perl_global_request_save(aTHX_ r);

    /* default is +SetupEnv, skip if PerlOption -SetupEnv */
    if (MpDirSETUP_ENV(dcfg) || !MpDirSeenSETUP_ENV(dcfg)) {
        modperl_env_request_populate(aTHX_ r);
    }

    /* default is +GlobalRequest, skip if PerlOption -GlobalRequest */
    if (MpDirGLOBAL_REQUEST(dcfg) || !MpDirSeenGLOBAL_REQUEST(dcfg)) {
        modperl_global_request_set(r);
    }

    /* need to create a block around the IO setup so the temp vars
     * will be automatically cleaned up when we are done with IO */
    ENTER;SAVETMPS;
    h_stdin  = modperl_io_override_stdin(aTHX_ r);
    h_stdout = modperl_io_override_stdout(aTHX_ r);

    modperl_env_request_tie(aTHX_ r);

    retval = modperl_response_handler_run(r);

    modperl_env_request_untie(aTHX_ r);

    modperl_perl_global_request_restore(aTHX_ r);

    modperl_io_restore_stdin(aTHX_ h_stdin);
    modperl_io_restore_stdout(aTHX_ h_stdout);
    FREETMPS;LEAVE;

#ifdef USE_ITHREADS
    if (MpInterpPUTBACK(interp)) {
        /* PerlInterpScope handler */
        modperl_interp_unselect(interp);
        rcfg->interp = NULL;
    }
#endif

    /* flush output buffer after interpreter is putback */
    rc = modperl_response_finish(r);
    if (rc != APR_SUCCESS) {
        retval = rc;
    }

    switch (rcfg->status) {
      case HTTP_MOVED_TEMPORARILY:
        /* set by modperl_cgi_header_parse */
        retval = HTTP_MOVED_TEMPORARILY;
        break;
    }

    return retval;
}

/* This ugly hack pulls in any function listed in
 * modperl_exports.c. Otherwise, the over-zealous
 * linker would remove unused api functions
 */
const void *modperl_suck_in_ugly_hack(void);
const void *modperl_suck_in_ugly_hack(void)
{
    extern const void *modperl_ugly_hack;
    return modperl_ugly_hack;
}

module AP_MODULE_DECLARE_DATA perl_module = {
    STANDARD20_MODULE_STUFF,
    modperl_config_dir_create, /* dir config creater */
    modperl_config_dir_merge,  /* dir merger --- default is to override */
    modperl_config_srv_create, /* server config */
    modperl_config_srv_merge,  /* merge server config */
    modperl_cmds,              /* table of config file commands       */
    modperl_register_hooks,    /* register hooks */
};
