/* ====================================================================
 * Copyright (c) 1995-1998 The Apache Group.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer. 
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in
 *    the documentation and/or other materials provided with the
 *    distribution.
 *
 * 3. All advertising materials mentioning features or use of this
 *    software must display the following acknowledgment:
 *    "This product includes software developed by the Apache Group
 *    for use in the Apache HTTP server project (http://www.apache.org/)."
 *
 * 4. The names "Apache Server" and "Apache Group" must not be used to
 *    endorse or promote products derived from this software without
 *    prior written permission.
 *
 * 5. Redistributions of any form whatsoever must retain the following
 *    acknowledgment:
 *    "This product includes software developed by the Apache Group
 *    for use in the Apache HTTP server project (http://www.apache.org/)."
 *
 * THIS SOFTWARE IS PROVIDED BY THE APACHE GROUP ``AS IS'' AND ANY
 * EXPRESSED OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE APACHE GROUP OR
 * ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 * ====================================================================
 *
 * This software consists of voluntary contributions made by many
 * individuals on behalf of the Apache Group and was originally based
 * on public domain software written at the National Center for
 * Supercomputing Applications, University of Illinois, Urbana-Champaign.
 * For more information on the Apache Group and the Apache HTTP server
 * project, please see <http://www.apache.org/>.
 *
 */

/* 
 * And so it was decided the camel should be given magical multi-colored
 * feathers so it could fly and journey to once unknown worlds.
 * And so it was done...
 */

#define CORE_PRIVATE 
#include "mod_perl.h"

#ifdef WIN32
void *mod_perl_mutex = &mod_perl_mutex;
#else
void *mod_perl_dummy_mutex = &mod_perl_dummy_mutex;
#endif

static IV mp_request_rec;
static int seqno = 0;
static int perl_is_running = 0;
int mod_perl_socketexitoption = 3;
int mod_perl_weareaforkedchild = 0;     
static int callbacks_this_request = 0;
static PerlInterpreter *perl = NULL;
static AV *orig_inc = Nullav;
static AV *cleanup_av = Nullav;
#ifdef PERL_STACKED_HANDLERS
static HV *stacked_handlers = Nullhv;
#endif

#ifdef PERL_OBJECT
CPerlObj *pPerl;
#endif

static command_rec perl_cmds[] = {
#ifdef PERL_SECTIONS
    { "<Perl>", perl_section, NULL, OR_ALL, RAW_ARGS, "Perl code" },
    { "</Perl>", perl_end_section, NULL, OR_ALL, NO_ARGS, "End Perl code" },
#endif
    { "=pod", perl_pod_section, NULL, OR_ALL, RAW_ARGS, "Start of POD" },
    { "=end", perl_pod_section, NULL, OR_ALL, RAW_ARGS, "End of =begin" },
    { "=cut", perl_pod_end_section, NULL, OR_ALL, NO_ARGS, "End of POD" },
    { "__END__", perl_config_END, NULL, OR_ALL, RAW_ARGS, "Stop reading config" },
    { "PerlFreshRestart", perl_cmd_fresh_restart,
      NULL,
      RSRC_CONF, FLAG, "Tell mod_perl to reload modules and flush Apache::Registry cache on restart" },
    { "PerlTaintCheck", perl_cmd_tainting,
      NULL,
      RSRC_CONF, FLAG, "Turn on -T switch" },
#ifdef PERL_SAFE_STARTUP
    { "PerlOpmask", perl_cmd_opmask,
      NULL,
      RSRC_CONF, TAKE1, "Opmask File" },
#endif
    { "PerlWarn", perl_cmd_warn,
      NULL,
      RSRC_CONF, FLAG, "Turn on -w switch" },
    { "PerlScript", perl_cmd_require,
      NULL,
      OR_ALL, ITERATE, "this directive is deprecated, use `PerlRequire'" },
    { "PerlRequire", perl_cmd_require,
      NULL,
      OR_ALL, ITERATE, "A Perl script name, pulled in via require" },
    { "PerlModule", perl_cmd_module,
      NULL,
      OR_ALL, ITERATE, "List of Perl modules" },
    { "PerlSetVar", perl_cmd_var,
      NULL,
      OR_ALL, TAKE2, "Perl config var and value" },
    { "PerlSetEnv", perl_cmd_setenv,
      NULL,
      OR_ALL, TAKE2, "Perl %ENV key and value" },
    { "PerlPassEnv", perl_cmd_pass_env, 
      NULL,
      RSRC_CONF, ITERATE, "pass environment variables to %ENV"},  
    { "PerlSendHeader", perl_cmd_sendheader,
      NULL,
      OR_ALL, FLAG, "Tell mod_perl to parse and send HTTP headers" },
    { "PerlSetupEnv", perl_cmd_env,
      NULL,
      OR_ALL, FLAG, "Tell mod_perl to setup %ENV by default" },
    { "PerlHandler", perl_cmd_handler_handlers,
      NULL,
      OR_ALL, ITERATE, "the Perl handler routine name" },
#ifdef PERL_TRANS
    { PERL_TRANS_CMD_ENTRY },
#endif
#ifdef PERL_AUTHEN
    { PERL_AUTHEN_CMD_ENTRY },
#endif
#ifdef PERL_AUTHZ
    { PERL_AUTHZ_CMD_ENTRY },
#endif
#ifdef PERL_ACCESS
    { PERL_ACCESS_CMD_ENTRY },
#endif
#ifdef PERL_TYPE
    { PERL_TYPE_CMD_ENTRY },
#endif
#ifdef PERL_FIXUP
    { PERL_FIXUP_CMD_ENTRY },
#endif
#ifdef PERL_LOG
    { PERL_LOG_CMD_ENTRY },
#endif
#ifdef PERL_CLEANUP
    { PERL_CLEANUP_CMD_ENTRY },
#endif
#ifdef PERL_INIT
    { PERL_INIT_CMD_ENTRY },
#endif
#ifdef PERL_HEADER_PARSER
    { PERL_HEADER_PARSER_CMD_ENTRY },
#endif
#ifdef PERL_CHILD_INIT
    { PERL_CHILD_INIT_CMD_ENTRY },
#endif
#ifdef PERL_CHILD_EXIT
    { PERL_CHILD_EXIT_CMD_ENTRY },
#endif
#ifdef PERL_POST_READ_REQUEST
    { PERL_POST_READ_REQUEST_CMD_ENTRY },
#endif
#ifdef PERL_DISPATCH
    { PERL_DISPATCH_CMD_ENTRY },
#endif
#ifdef PERL_RESTART
    { PERL_RESTART_CMD_ENTRY },
#endif
    { NULL }
};

static handler_rec perl_handlers [] = {
    { "perl-script", perl_handler },
    { DIR_MAGIC_TYPE, perl_handler },
    { NULL }
};

module MODULE_VAR_EXPORT perl_module = {
    STANDARD_MODULE_STUFF,
    perl_startup,                 /* initializer */
    perl_create_dir_config,    /* create per-directory config structure */
    perl_merge_dir_config,     /* merge per-directory config structures */
    perl_create_server_config, /* create per-server config structure */
    NULL,                      /* merge per-server config structures */
    perl_cmds,                 /* command table */
    perl_handlers,             /* handlers */
    PERL_TRANS_HOOK,           /* translate_handler */
    PERL_AUTHEN_HOOK,          /* check_user_id */
    PERL_AUTHZ_HOOK,           /* check auth */
    PERL_ACCESS_HOOK,          /* check access */
    PERL_TYPE_HOOK,            /* type_checker */
    PERL_FIXUP_HOOK,           /* pre-run fixups */
    PERL_LOG_HOOK,          /* logger */
#if MODULE_MAGIC_NUMBER >= 19970103
    PERL_HEADER_PARSER_HOOK,   /* header parser */
#endif
#if MODULE_MAGIC_NUMBER >= 19970719
    PERL_CHILD_INIT_HOOK,   /* child_init */
#endif
#if MODULE_MAGIC_NUMBER >= 19970728
    NULL,   /* child_exit *//* mod_perl uses register_cleanup() */
#endif
#if MODULE_MAGIC_NUMBER >= 19970825
    PERL_POST_READ_REQUEST_HOOK,   /* post_read_request */
#endif
};

#if defined(STRONGHOLD) && !defined(APACHE_SSL)
#define APACHE_SSL
#endif

int PERL_RUNNING (void) 
{
    return (perl_is_running);
}

static void seqno_check_max(request_rec *r, int seqno)
{
    dPPDIR;
    char *max = NULL;
    array_header *vars = (array_header *)cld->vars;

    /* XXX: what triggers such a condition ?*/
    if(vars && (vars->nelts > 100000)) {
	fprintf(stderr, "[warning] PerlSetVar->nelts = %d\n", vars->nelts);
    }
    else {
      if(cld->vars)
	  max = (char *)table_get(cld->vars, "MaxModPerlRequestsPerChild");
    }

#if (MODULE_MAGIC_NUMBER >= 19970912) && !defined(WIN32)
    if(max && (seqno >= atoi(max))) {
	child_terminate(r);
	MP_TRACE_g(fprintf(stderr, "mod_perl: terminating child %d after serving %d requests\n", 
		(int)getpid(), seqno));
    }
#endif
    max = NULL; 
}

void perl_shutdown (server_rec *s, pool *p)
{
    char *pdl = NULL;

    if((pdl = getenv("PERL_DESTRUCT_LEVEL")))
	perl_destruct_level = atoi(pdl);
    else
	perl_destruct_level = PERL_DESTRUCT_LEVEL;

    if(perl_destruct_level < 0) {
	MP_TRACE_g(fprintf(stderr, 
			   "skipping destruction of Perl interpreter\n"));
	return;
    }

    /* execute END blocks we suspended during perl_startup() */
    perl_run_endav("perl_shutdown"); 

    MP_TRACE_g(fprintf(stderr, 
		     "destructing and freeing Perl interpreter..."));

    perl_util_cleanup();

    mp_request_rec = 0;

    av_undef(orig_inc);
    SvREFCNT_dec((SV*)orig_inc);
    orig_inc = Nullav;

    av_undef(cleanup_av);
    SvREFCNT_dec((SV*)cleanup_av);
    cleanup_av = Nullav;

#ifdef PERL_STACKED_HANDLERS
    hv_undef(stacked_handlers);
    SvREFCNT_dec((SV*)stacked_handlers);
    stacked_handlers = Nullhv;
#endif
    
    perl_destruct(perl);
    perl_free(perl);

#ifdef USE_THREADS
    PERL_SYS_TERM();
#endif

    perl_is_running = 0;
    MP_TRACE_g(fprintf(stderr, "ok\n"));
}

request_rec *mp_fake_request_rec(server_rec *s, pool *p, char *hook)
{
    request_rec *r = (request_rec *)palloc(p, sizeof(request_rec));
    r->pool = p; 
    r->server = s;
    r->per_dir_config = NULL;
    r->uri = hook;
    return r;
}

#ifdef PERL_RESTART
void perl_restart_handler(server_rec *s, pool *p)
{
    char *hook = "PerlRestartHandler";
    dSTATUS;
    dPSRV(s);
    request_rec *r = mp_fake_request_rec(s, p, hook);
    PERL_CALLBACK(hook, cls->PerlRestartHandler);   
}
#endif

void perl_restart(server_rec *s, pool *p)
{
    /* restart as best we can */
    SV *rgy_cache = perl_get_sv("Apache::Registry", FALSE);
    HV *rgy_symtab = (HV*)gv_stashpv("Apache::ROOT", FALSE);

    ENTER;

    SAVESPTR(warnhook);
    warnhook = perl_eval_pv("sub {}", TRUE);

    /* the file-stat cache */
    if(rgy_cache)
	sv_setsv(rgy_cache, &sv_undef);

    /* the symbol table we compile registry scripts into */
    if(rgy_symtab)
	hv_clear(rgy_symtab);

    if(endav) {
	SvREFCNT_dec(endav);
	endav = Nullav;
    }

#ifdef STACKED_HANDLERS
    if(stacked_handlers) 
	hv_clear(stacked_handlers);
#endif

    /* reload %INC */
    perl_reload_inc();

    LEAVE;

    /*mod_perl_notice(s, "mod_perl restarted"); */
    MP_TRACE_g(fprintf(stderr, "perl_restart: ok\n"));
}

U32 mp_debug = 0;

static void mod_perl_set_cwd(void)
{
    char *name = "Apache::Server::CWD";
    GV *gv = gv_fetchpv(name, GV_ADDMULTI, SVt_PV);
    char *pwd = getenv("PWD");

    if(pwd) 
	sv_setpv(GvSV(gv), pwd);
    else 
	sv_setsv(GvSV(gv), 
		 perl_eval_pv("require Cwd; Cwd::getcwd()", TRUE));

    mod_perl_untaint(GvSV(gv));
}

#ifdef PERL_TIE_SCRIPTNAME
static I32 scriptname_val(IV ix, SV* sv)
{ 
    dTHR;
    request_rec *r = perl_request_rec(NULL);
    if(r) 
	sv_setpv(sv, r->filename);
    else if(strNE(SvPVX(GvSV(curcop->cop_filegv)), "-e"))
	sv_setsv(sv, GvSV(curcop->cop_filegv));
    else {
	SV *file = perl_eval_pv("(caller())[1]",TRUE);
	sv_setsv(sv, file);
    }
    MP_TRACE_g(fprintf(stderr, "FETCH $0 => %s\n", SvPV(sv,na)));
    return TRUE;
}

static void mod_perl_tie_scriptname(void)
{
    SV *sv = perl_get_sv("0",TRUE);
    struct ufuncs umg;
    umg.uf_val = scriptname_val;
    umg.uf_set = NULL;
    umg.uf_index = (IV)0;
    sv_unmagic(sv, 'U');
    sv_magic(sv, Nullsv, 'U', (char*) &umg, sizeof(umg));
}
#else
#define mod_perl_tie_scriptname()
#endif

#define saveINC \
    if(orig_inc) SvREFCNT_dec(orig_inc); \
    orig_inc = av_copy_array(GvAV(incgv))

static void mp_dso_unload(void *data) 
{ 
    perl_is_running = 0; 
} 

void perl_startup (server_rec *s, pool *p)
{
    char *argv[] = { NULL, NULL, NULL, NULL, NULL, NULL, NULL };
    char **list, *dstr;
    int status, i, argc=1;
    char *dash_e = "BEGIN { $ENV{MOD_PERL} = 1; $ENV{GATEWAY_INTERFACE} = 'CGI-Perl/1.1'; }";
    char *line_info = "#line 1 mod_perl";
    dPSRV(s);
    SV *pool_rv, *server_rv;
    GV *gv, *shgv;

#if MODULE_MAGIC_NUMBER >= 19980507
#ifndef MOD_PERL_STRING_VERSION
#include "mod_perl_version.h"
#endif
    ap_add_version_component(MOD_PERL_STRING_VERSION);
#endif

#ifndef WIN32
    argv[0] = server_argv0;
#endif

#ifdef PERL_TRACE
    if((dstr = getenv("MOD_PERL_TRACE"))) {
	if(strEQ(dstr, "all")) {
	    mp_debug = 0xffffffff;
	}
	else if (isALPHA(dstr[0])) {
	    static char debopts[] = "dshgc";
	    char *d;

	    for (; *dstr && (d = strchr(debopts,*dstr)); dstr++) 
		mp_debug |= 1 << (d - debopts);
	}
	else {
	    mp_debug = atoi(dstr);
	}
	mp_debug |= 0x80000000;
    }
#else
    dstr = NULL;
#endif

    if(perl_is_running == 0) {
	/* we'll boot Perl below */
    }
    else if(perl_is_running < PERL_DONE_STARTUP) {
	/* skip the -HUP at server-startup */
	perl_is_running++;
	MP_TRACE_g(fprintf(stderr, "perl_startup: perl aleady running...ok\n"));
	return;
    }
    else {
	Apache__ServerReStarting(TRUE);

#ifdef PERL_RESTART
	perl_restart_handler(s, p);
#endif
	if(cls->FreshRestart)
	    perl_restart(s, p);

	Apache__ServerReStarting(FALSE);

	return;
    }
    perl_is_running++;

    /* fake-up what the shell usually gives perl */
    if(cls->PerlTaintCheck) 
	argv[argc++] = "-T";

    if(cls->PerlWarn)
	argv[argc++] = "-w";

#ifdef PERL_MARK_WHERE
    argv[argc++] = "-e";
    argv[argc++] = line_info;
#else
    line_info = NULL; 
#endif

    argv[argc++] = "-e";
    argv[argc++] = dash_e;

    MP_TRACE_g(fprintf(stderr, "perl_parse args: "));
    for(i=1; i<argc; i++)
	MP_TRACE_g(fprintf(stderr, "'%s' ", argv[i]));
    MP_TRACE_g(fprintf(stderr, "..."));

#ifdef USE_THREADS
# ifdef PERL_SYS_INIT
    PERL_SYS_INIT(&argc,&argv);
# endif
#endif

    perl_init_i18nl10n(1);

    MP_TRACE_g(fprintf(stderr, "allocating perl interpreter..."));
    if((perl = perl_alloc()) == NULL) {
	MP_TRACE_g(fprintf(stderr, "not ok\n"));
	perror("alloc");
	exit(1);
    }
    MP_TRACE_g(fprintf(stderr, "ok\n"));
  
    MP_TRACE_g(fprintf(stderr, "constructing perl interpreter...ok\n"));
    perl_construct(perl);

    status = perl_parse(perl, xs_init, argc, argv, NULL);
    if (status != OK) {
	MP_TRACE_g(fprintf(stderr,"not ok, status=%d\n", status));
	perror("parse");
	exit(1);
    }
    MP_TRACE_g(fprintf(stderr, "ok\n"));

    perl_clear_env();
    mod_perl_pass_env(p, cls);
    mod_perl_set_cwd();
    mod_perl_tie_scriptname();
    MP_TRACE_g(fprintf(stderr, "running perl interpreter..."));

    pool_rv = perl_get_sv("Apache::__POOL", TRUE);
    sv_setref_pv(pool_rv, Nullch, (void*)p);
    server_rv = perl_get_sv("Apache::__SERVER", TRUE);
    sv_setref_pv(server_rv, Nullch, (void*)s);

    gv = GvSV_init("Apache::ERRSV_CAN_BE_HTTP");
#ifdef ERRSV_CAN_BE_HTTP
    GvSV_setiv(gv, TRUE);
#endif

    gv = GvSV_init("Apache::__T");
    if(cls->PerlTaintCheck) 
	GvSV_setiv(gv, TRUE);
    SvREADONLY_on(GvSV(gv));

    (void)GvSV_init("Apache::__SendHeader");
    (void)GvSV_init("Apache::__CurrentCallback");
    (void)GvHV_init("mod_perl::UNIMPORT");

    Apache__ServerReStarting(FALSE); /* just for -w */
    Apache__ServerStarting(PERL_RUNNING());

#ifdef PERL_STACKED_HANDLERS
    if(!stacked_handlers) {
	stacked_handlers = newHV();
	shgv = GvHV_init("Apache::PerlStackedHandlers");
	GvHV(shgv) = stacked_handlers;
    }
#endif 
#ifdef MULTITHREAD
    mod_perl_mutex = create_mutex(NULL);
#endif

    if ((status = perl_run(perl)) != OK) {
	MP_TRACE_g(fprintf(stderr,"not ok, status=%d\n", status));
	perror("run");
	exit(1);
    }
    MP_TRACE_g(fprintf(stderr, "ok\n"));

    {
	dTHR;
	TAINT_NOT; /* At this time all is safe */
    }

    av_push(GvAV(incgv), newSVpv(server_root_relative(p,""),0));
    av_push(GvAV(incgv), newSVpv(server_root_relative(p,"lib/perl"),0));

    /* *CORE::GLOBAL::exit = \&Apache::exit */
    if(gv_stashpv("CORE::GLOBAL", FALSE)) {
	GV *exitgp = gv_fetchpv("CORE::GLOBAL::exit", TRUE, SVt_PVCV);
	GvCV(exitgp) = perl_get_cv("Apache::exit", TRUE);
	GvIMPORTED_CV_on(exitgp);
    }

    if(PERL_STARTUP_DONE_CHECK && !getenv("PERL_STARTUP_DONE")) {
	MP_TRACE_g(fprintf(stderr, 
			   "mod_perl: PerlModule,PerlRequire postponed\n"));
	my_setenv("PERL_STARTUP_DONE", "1");
	saveINC;
	Apache__ServerStarting(FALSE);
	return;
    }

    ENTER_SAFE(s,p);
    MP_TRACE_g(mod_perl_dump_opmask());

    list = (char **)cls->PerlRequire->elts;
    for(i = 0; i < cls->PerlRequire->nelts; i++) {
	if(perl_load_startup_script(s, p, list[i], TRUE) != OK) {
	    fprintf(stderr, "Require of Perl file `%s' failed, exiting...\n", 
		    list[i]);
	    exit(1);
	}
    }

    list = (char **)cls->PerlModule->elts;
    for(i = 0; i < cls->PerlModule->nelts; i++) {
	if(perl_require_module(list[i], s) != OK) {
	    fprintf(stderr, "Can't load Perl module `%s', exiting...\n", 
		    list[i]);
	    exit(1);
	}
    }

    LEAVE_SAFE;

    MP_TRACE_g(fprintf(stderr, 
	     "mod_perl: %d END blocks encountered during server startup\n",
	     endav ? (int)AvFILL(endav)+1 : 0));
#if MODULE_MAGIC_NUMBER < 19970728
    if(endav)
	MP_TRACE_g(fprintf(stderr, "mod_perl: cannot run END blocks encoutered at server startup without apache_1.3.0+\n"));
#endif

    saveINC;
    Apache__ServerStarting(FALSE);
#if MODULE_MAGIC_NUMBER >= MMN_130
    if(perl_module.dynamic_load_handle) 
	register_cleanup(p, NULL, mp_dso_unload, NULL); 
#endif
}

int mod_perl_sent_header(request_rec *r, int val)
{
    dPPDIR;

    if(val) MP_SENTHDR_on(cld);
    val = MP_SENTHDR(cld) ? 1 : 0;
    return MP_SENDHDR(cld) ? val : 1;
}

#ifndef perl_init_ids
#define perl_init_ids mod_perl_init_ids()
#endif

int perl_handler(request_rec *r)
{
    dSTATUS;
    dPPDIR;
    dTHR;
    SV *nwvh = Nullsv;

    (void)acquire_mutex(mod_perl_mutex);
    
#if 0
    /* force 'PerlSendHeader On' for sub-requests
     * e.g. Apache::Sandwich 
     */
    if(r->main != NULL)
	MP_SENDHDR_on(cld); 
#endif

    if(MP_SENDHDR(cld)) 
	MP_SENTHDR_off(cld);

    table_set(r->subprocess_env, "MOD_PERL", MOD_PERL_VERSION);

    (void)perl_request_rec(r); 

    MP_TRACE_g(fprintf(stderr, "perl_handler ENTER: SVs = %5d, OBJs = %5d\n",
		     (int)sv_count, (int)sv_objcount));
    ENTER;
    SAVETMPS;

    if((nwvh = ApachePerlRun_name_with_virtualhost())) {
	if(!r->server->is_virtual) {
	    SAVESPTR(nwvh);
	    sv_setiv(nwvh, 0);
	}
    }

    save_hptr(&GvHV(siggv)); 

    save_aptr(&endav); 
    endav = Nullav;

    /* hookup STDIN & STDOUT to the client */
    perl_stdout2client(r);
    perl_stdin2client(r);

    if(MP_ENV(cld)) 
	perl_setup_env(r);

    PERL_CALLBACK("PerlHandler", cld->PerlHandler);

    FREETMPS;
    LEAVE;
    MP_TRACE_g(fprintf(stderr, "perl_handler LEAVE: SVs = %5d, OBJs = %5d\n", 
		     (int)sv_count, (int)sv_objcount));

    (void)release_mutex(mod_perl_mutex);
    return status;
}

#ifdef PERL_CHILD_INIT

typedef struct {
    server_rec *server;
    pool *pool;
} server_hook_args;

static void perl_child_exit_cleanup(void *data)
{
    server_hook_args *args = (server_hook_args *)data;
    PERL_CHILD_EXIT_HOOK(args->server, args->pool);
}

void PERL_CHILD_INIT_HOOK(server_rec *s, pool *p)
{
    char *hook = "PerlChildInitHandler";
    dSTATUS;
    dPSRV(s);
    request_rec *r = mp_fake_request_rec(s, p, hook);
    server_hook_args *args = 
	(server_hook_args *)palloc(p, sizeof(server_hook_args));

    args->server = s;
    args->pool = p;
    register_cleanup(p, args, perl_child_exit_cleanup, null_cleanup);

    mod_perl_init_ids();
    PERL_CALLBACK(hook, cls->PerlChildInitHandler);
}
#endif

#ifdef PERL_CHILD_EXIT
void PERL_CHILD_EXIT_HOOK(server_rec *s, pool *p)
{
    char *hook = "PerlChildExitHandler";
    dSTATUS;
    dPSRV(s);
    request_rec *r = mp_fake_request_rec(s, p, hook);

    PERL_CALLBACK(hook, cls->PerlChildExitHandler);

    perl_shutdown(s,p);
}
#endif

#ifdef PERL_POST_READ_REQUEST
int PERL_POST_READ_REQUEST_HOOK(request_rec *r)
{
    dSTATUS;
    dPSRV(r->server);
#if MODULE_MAGIC_NUMBER > 19980270
    if(r->parsed_uri.scheme && r->parsed_uri.hostname) {
	r->proxyreq = 1;
	r->uri = r->unparsed_uri;
    }
#endif
#ifdef PERL_INIT
    PERL_CALLBACK("PerlInitHandler", cls->PerlInitHandler);
#endif
    PERL_CALLBACK("PerlPostReadRequestHandler", cls->PerlPostReadRequestHandler);
    return status;
}
#endif

#ifdef PERL_TRANS
int PERL_TRANS_HOOK(request_rec *r)
{
    dSTATUS;
    dPSRV(r->server);
    PERL_CALLBACK("PerlTransHandler", cls->PerlTransHandler);
    return status;
}
#endif

#ifdef PERL_HEADER_PARSER
int PERL_HEADER_PARSER_HOOK(request_rec *r)
{
    dSTATUS;
    dPPDIR;
#ifdef PERL_INIT
    PERL_CALLBACK("PerlInitHandler", 
			 cld->PerlInitHandler);
#endif
    PERL_CALLBACK("PerlHeaderParserHandler", 
			 cld->PerlHeaderParserHandler);
    return status;
}
#endif

#ifdef PERL_AUTHEN
int PERL_AUTHEN_HOOK(request_rec *r)
{
    dSTATUS;
    dPPDIR;
    PERL_CALLBACK("PerlAuthenHandler", cld->PerlAuthenHandler);
    return status;
}
#endif

#ifdef PERL_AUTHZ
int PERL_AUTHZ_HOOK(request_rec *r)
{
    dSTATUS;
    dPPDIR;
    PERL_CALLBACK("PerlAuthzHandler", cld->PerlAuthzHandler);
    return status;
}
#endif

#ifdef PERL_ACCESS
int PERL_ACCESS_HOOK(request_rec *r)
{
    dSTATUS;
    dPPDIR;
    PERL_CALLBACK("PerlAccessHandler", cld->PerlAccessHandler);
    return status;
}
#endif

#ifdef PERL_TYPE
int PERL_TYPE_HOOK(request_rec *r)
{
    dSTATUS;
    dPPDIR;
    PERL_CALLBACK("PerlTypeHandler", cld->PerlTypeHandler);
    return status;
}
#endif

#ifdef PERL_FIXUP
int PERL_FIXUP_HOOK(request_rec *r)
{
    dSTATUS;
    dPPDIR;
    PERL_CALLBACK("PerlFixupHandler", cld->PerlFixupHandler);
    return status;
}
#endif

#ifdef PERL_LOG
int PERL_LOG_HOOK(request_rec *r)
{
    dSTATUS;
    dPPDIR;
    PERL_CALLBACK("PerlLogHandler", cld->PerlLogHandler);
    return status;
}
#endif

#define CleanupHandler cld->PerlCleanupHandler

#ifdef PERL_STACKED_HANDLERS
#define has_CleanupHandler (CleanupHandler && SvREFCNT(CleanupHandler))
#else
#define has_CleanupHandler CleanupHandler
#endif

void mod_perl_end_cleanup(void *data)
{
    request_rec *r = (request_rec *)data;
    dSTATUS;
    dPPDIR;

#ifdef PERL_CLEANUP
    if(has_CleanupHandler) {
	PERL_CALLBACK("PerlCleanupHandler", cld->PerlCleanupHandler);
    }
#endif

    MP_TRACE_g(fprintf(stderr, "perl_end_cleanup..."));
    perl_run_rgy_endav(r->uri);

    /* clear %ENV */
    perl_clear_env();

    /* reset @INC */
    av_undef(GvAV(incgv));
    SvREFCNT_dec(GvAV(incgv));
    GvAV(incgv) = Nullav;
    GvAV(incgv) = av_copy_array(orig_inc);

    /* reset $/ */
    sv_setpvn(GvSV(gv_fetchpv("/", FALSE, SVt_PV)), "\n", 1);

    {
	dTHR;
	/* %@ */
	hv_clear(ERRHV);
    }

    callbacks_this_request = 0;

#ifdef PERL_STACKED_HANDLERS
    /* reset Apache->push_handlers, but don't clear ExitHandler */
#define CH_EXIT_KEY "PerlChildExitHandler", 20
    {
	SV *exith = Nullsv;
	if(hv_exists(stacked_handlers, CH_EXIT_KEY)) {
	    exith = *hv_fetch(stacked_handlers, CH_EXIT_KEY, FALSE);
            /* inc the refcnt since hv_clear will dec it */
	    ++SvREFCNT(exith);
	}
	hv_clear(stacked_handlers);
	if(exith) 
	    hv_store(stacked_handlers, CH_EXIT_KEY, exith, FALSE);
    }

#endif

#ifdef USE_SFIO
    PerlIO_flush(PerlIO_stdout());
#endif

    MP_TRACE_g(fprintf(stderr, "ok\n"));
    (void)release_mutex(mod_perl_mutex); 
}

void mod_perl_cleanup_handler(void *data)
{
    request_rec *r = perl_request_rec(NULL);
    SV *cv;
    I32 i;
    dPPDIR;

    (void)acquire_mutex(mod_perl_mutex); 
    MP_TRACE_h(fprintf(stderr, "running registered cleanup handlers...\n")); 
    for(i=0; i<=AvFILL(cleanup_av); i++) { 
	cv = *av_fetch(cleanup_av, i, 0);
	MARK_WHERE("registered cleanup", cv);
	perl_call_handler(cv, (request_rec *)r, Nullav);
	UNMARK_WHERE;
    }
    av_clear(cleanup_av);
#ifndef WIN32
    if(cld) MP_RCLEANUP_off(cld);
#endif
    (void)release_mutex(mod_perl_mutex); 
}

#ifdef PERL_METHOD_HANDLERS
int perl_handler_ismethod(HV *class, char *sub)
{
    CV *cv;
    HV *stash;
    GV *gv;
    SV *sv;
    int is_method=0;

    if(!sub) return 0;
    sv = newSVpv(sub,0);
    if(!(cv = sv_2cv(sv, &stash, &gv, FALSE))) {
	GV *gvp = gv_fetchmethod(class, sub);
	if (gvp) cv = GvCV(gvp);
    }

    if (cv && SvPOK(cv)) 
	is_method = strnEQ(SvPVX(cv), "$$", 2);
    MP_TRACE_h(fprintf(stderr, "checking if `%s' is a method...%s\n", 
	   sub, (is_method ? "yes" : "no")));
    SvREFCNT_dec(sv);
    return is_method;
}
#endif

void mod_perl_noop(void *data) {}

void mod_perl_register_cleanup(request_rec *r, SV *sv)
{
    dPPDIR;

    if(!MP_RCLEANUP(cld)) {
	(void)perl_request_rec(r); 
	register_cleanup(r->pool, (void*)r,
			 mod_perl_cleanup_handler, mod_perl_noop);
	MP_RCLEANUP_on(cld);
	if(cleanup_av == Nullav) cleanup_av = newAV();
    }
    MP_TRACE_h(fprintf(stderr, "registering PerlCleanupHandler\n"));
    
    ++SvREFCNT(sv); av_push(cleanup_av, sv);
}

#ifdef PERL_STACKED_HANDLERS

int mod_perl_push_handlers(SV *self, char *hook, SV *sub, AV *handlers)
{
    int do_store=0, len=strlen(hook);
    SV **svp;

    if(self && SvTRUE(sub)) {
	if(handlers == Nullav) {
	    svp = hv_fetch(stacked_handlers, hook, len, 0);
	    MP_TRACE_h(fprintf(stderr, "fetching %s stack\n", hook));
	    if(svp && SvTRUE(*svp) && SvROK(*svp)) {
		handlers = (AV*)SvRV(*svp);
	    }
	    else {
		MP_TRACE_h(fprintf(stderr, "%s handlers stack undef, creating\n", hook));
		handlers = newAV();
		do_store = 1;
	    }
	}
	    
	if(SvROK(sub) && (SvTYPE(SvRV(sub)) == SVt_PVCV)) {
	    MP_TRACE_h(fprintf(stderr, "pushing CODE ref into `%s' handlers\n", hook));
	}
	else if(SvPOK(sub)) {
	    if(do_store) {
		MP_TRACE_h(fprintf(stderr, 
				   "pushing `%s' into `%s' handlers\n", 
				   SvPV(sub,na), hook));
	    }
	    else {
		MP_TRACE_d(fprintf(stderr, 
				   "pushing `%s' into `%s' handlers\n", 
				   SvPV(sub,na), hook));
	    }
	}
	else {
	    warn("mod_perl_push_handlers: Not a subroutine name or CODE reference!");
	}

	++SvREFCNT(sub); av_push(handlers, sub);

	if(do_store) 
	    hv_store(stacked_handlers, hook, len, 
		     (SV*)newRV_noinc((SV*)handlers), 0);
	return 1;
    }
    return 0;
}

int perl_run_stacked_handlers(char *hook, request_rec *r, AV *handlers)
{
    dSTATUS;
    I32 i, do_clear=FALSE;
    SV *sub, **svp; 
    int hook_len = strlen(hook);

    if(handlers == Nullav) {
	if(hv_exists(stacked_handlers, hook, hook_len)) {
	   svp = hv_fetch(stacked_handlers, hook, hook_len, 0);
	   if(svp && SvROK(*svp)) 
	       handlers = (AV*)SvRV(*svp);
	}
	else {
	    MP_TRACE_h(fprintf(stderr, "`%s' push_handlers() stack is empty\n", hook));
	    return NO_HANDLERS;
	}
	do_clear = TRUE;
	MP_TRACE_h(fprintf(stderr, 
		 "running %d pushed (stacked) handlers for %s...\n", 
			 (int)AvFILL(handlers)+1, r->uri)); 
    }
    else {
#ifdef PERL_STACKED_HANDLERS
      /* XXX: bizarre, 
	 I only see this with httpd.conf.pl and PerlAccessHandler */
	if(SvTYPE((SV*)handlers) != SVt_PVAV) {
	    fprintf(stderr, "[warning] %s stack is not an ARRAY!\n", hook);
	    sv_dump((SV*)handlers);
	    return DECLINED;
	}
#endif
	MP_TRACE_h(fprintf(stderr, 
		 "running %d server configured stacked handlers for %s...\n", 
			 (int)AvFILL(handlers)+1, r->uri)); 
    }
    for(i=0; i<=AvFILL(handlers); i++) {
	MP_TRACE_h(fprintf(stderr, "calling &{%s->[%d]} (%d total)\n", 
			   hook, (int)i, (int)AvFILL(handlers)+1));

	if(!(sub = *av_fetch(handlers, i, FALSE))) {
	    MP_TRACE_h(fprintf(stderr, "sub not defined!\n"));
	}
	else {
	    if(!SvTRUE(sub)) {
		MP_TRACE_h(fprintf(stderr, "sub undef!  skipping callback...\n"));
		continue;
	    }

	    MARK_WHERE(hook, sub);
	    status = perl_call_handler(sub, r, Nullav);
	    UNMARK_WHERE;
	    MP_TRACE_h(fprintf(stderr, "&{%s->[%d]} returned status=%d\n",
			       hook, (int)i, status));
	    if((status != OK) && (status != DECLINED)) {
		if(do_clear)
		    av_clear(handlers);	
		return status;
	    }
	}
    }
    if(do_clear)
	av_clear(handlers);	
    return status;
}

#endif /* PERL_STACKED_HANDLERS */

/* things to do once per-request */
void perl_per_request_init(request_rec *r)
{
    dPPDIR;

    /* PerlSetEnv */
    mod_perl_dir_env(cld);

    /* PerlSendHeader */
    if(MP_SENDHDR(cld)) {
	MP_SENTHDR_off(cld);
	table_set(r->subprocess_env, 
		  "PERL_SEND_HEADER", "On");
    }
    else
	MP_SENTHDR_on(cld);

    /* SetEnv PERL5LIB */
    if(!MP_INCPUSH(cld)) {
	char *path = (char *)table_get(r->subprocess_env, "PERL5LIB");
	if(path) {
	    perl_incpush(path);
	    MP_INCPUSH_on(cld);
	}
    }

    if(callbacks_this_request++ > 0) return;

    {
	dPSRV(r->server);
	mod_perl_pass_env(r->pool, cls);
    }
    mod_perl_tie_scriptname();
    /* will be released in mod_perl_end_cleanup */
    (void)acquire_mutex(mod_perl_mutex); 
    register_cleanup(r->pool, (void*)r, mod_perl_end_cleanup, mod_perl_noop);

#ifdef WIN32
    sv_setpvf(perl_get_sv("Apache::CurrentThreadId", TRUE), "0x%lx",
	      (unsigned long)GetCurrentThreadId());
#endif

    /* hookup stderr to error_log */
#ifndef PERL_TRACE
    if(r->server->error_log) 
	error_log2stderr(r->server);
#endif

    seqno++;
    MP_TRACE_g(fprintf(stderr, "mod_perl: inc seqno to %d for %s\n", seqno, r->uri));
    seqno_check_max(r, seqno);

    /* set $$, $>, etc., if 1.3a1+, this really happens during child_init */
    perl_init_ids; 
}

/* XXX this still needs work, getting there... */
int perl_call_handler(SV *sv, request_rec *r, AV *args)
{
    int count, status, is_method=0;
    dSP;
    perl_dir_config *cld = NULL;
    HV *stash = Nullhv;
    SV *class = newSVsv(sv), *dispsv = Nullsv;
    CV *cv = Nullcv;
    char *method = "handler";
    int defined_sub = 0, anon = 0;
    char *dispatcher = NULL;

    if(r->per_dir_config)
	cld = get_module_config(r->per_dir_config, &perl_module);

#ifdef PERL_DISPATCH
    if(cld && (dispatcher = cld->PerlDispatchHandler)) {
	if(!(dispsv = (SV*)perl_get_cv(dispatcher, FALSE))) {
	    if(strlen(dispatcher) > 0) { /* XXX */
		fprintf(stderr, 
			"mod_perl: unable to fetch PerlDispatchHandler `%s'\n",
			dispatcher); 
	    }
	    dispatcher = NULL;
	}
    }
#endif

    if(r->per_dir_config)
	perl_per_request_init(r);

    if(!dispatcher && (SvTYPE(sv) == SVt_PV)) {
	char *imp = pstrdup(r->pool, (char *)SvPV(class,na));

	if((anon = strnEQ(imp,"sub ",4))) {
	    sv = perl_eval_pv(imp, FALSE);
	    MP_TRACE_h(fprintf(stderr, "perl_call: caching CV pointer to `__ANON__'\n"));
	    defined_sub++;
	    goto callback; /* XXX, I swear I've never used goto before! */
	}


#ifdef PERL_METHOD_HANDLERS
	{
	    char *end_class = NULL;

	    if ((end_class = strstr(imp, "->"))) {
		end_class[0] = '\0';
		if(class)
		    SvREFCNT_dec(class);
		class = newSVpv(imp, 0);
		end_class[0] = ':';
		end_class[1] = ':';
		method = &end_class[2];
		imp = method;
		++is_method;
	    }
	}

	if(*SvPVX(class) == '$') {
	    SV *obj = perl_eval_pv(SvPVX(class), TRUE);
	    if(SvROK(obj) && sv_isobject(obj)) {
		MP_TRACE_h(fprintf(stderr, "handler object %s isa %s\n",
				   SvPVX(class),  HvNAME(SvSTASH((SV*)SvRV(obj)))));
		SvREFCNT_dec(class);
		class = obj;
		++SvREFCNT(class); /* this will _dec later */
		stash = SvSTASH((SV*)SvRV(class));
	    }
	}

	if(class && !stash) stash = gv_stashpv(SvPV(class,na),FALSE);
	   
#if 0
	MP_TRACE_h(fprintf(stderr, "perl_call: class=`%s'\n", SvPV(class,na)));
	MP_TRACE_h(fprintf(stderr, "perl_call: imp=`%s'\n", imp));
	MP_TRACE_h(fprintf(stderr, "perl_call: method=`%s'\n", method));
	MP_TRACE_h(fprintf(stderr, "perl_call: stash=`%s'\n", 
			 stash ? HvNAME(stash) : "unknown"));
#endif

#else
	method = NULL; /* avoid warning */
#endif


    /* if a Perl*Handler is not a defined function name,
     * default to the class implementor's handler() function
     * attempt to load the class module if it is not already
     */
	if(!imp) imp = SvPV(sv,na);
	if(!stash) stash = gv_stashpv(imp,FALSE);
	if(!is_method)
	    defined_sub = (cv = perl_get_cv(imp, FALSE)) ? TRUE : FALSE;
#ifdef PERL_METHOD_HANDLERS
	if(!defined_sub && stash) {
	    GV *gvp;
	    MP_TRACE_h(fprintf(stderr, 
		   "perl_call: trying method lookup on `%s' in class `%s'...", 
		   method, HvNAME(stash)));
	    /* XXX Perl caches method lookups internally, 
	     * should we cache this lookup?
	     */
	    if((gvp = gv_fetchmethod(stash, method))) {
		cv = GvCV(gvp);
		MP_TRACE_h(fprintf(stderr, "found\n"));
		is_method = perl_handler_ismethod(stash, method);
	    }
	    else {
		MP_TRACE_h(fprintf(stderr, "not found\n"));
	    }
	}
#endif

	if(!stash && !defined_sub) {
	    MP_TRACE_h(fprintf(stderr, "%s symbol table not found, loading...\n", imp));
	    if(perl_require_module(imp, r->server) == OK)
		stash = gv_stashpv(imp,FALSE);
#ifdef PERL_METHOD_HANDLERS
	    if(stash) /* check again */
		is_method = perl_handler_ismethod(stash, method);
#endif
	}
	
	if(!is_method && !defined_sub) {
	    MP_TRACE_h(fprintf(stderr, 
			     "perl_call: defaulting to %s::handler\n", imp));
	    sv_catpv(sv, "::handler");
	}
	
#if 0 /* XXX: CV lookup cache disabled for now */
 	if(!is_method && defined_sub) { /* cache it */
	    MP_TRACE_h(fprintf(stderr, 
			     "perl_call: caching CV pointer to `%s'\n", 
			     (anon ? "__ANON__" : SvPV(sv,na))));
	    SvREFCNT_dec(sv);
 	    sv = (SV*)newRV((SV*)cv); /* let newRV inc the refcnt */
	}
#endif
    }
    else {
	MP_TRACE_h(fprintf(stderr, "perl_call: handler is a %s\n", 
			 dispatcher ? "dispatcher" : "cached CV"));
    }

callback:
    ENTER;
    SAVETMPS;
    PUSHMARK(sp);
#ifdef PERL_METHOD_HANDLERS
    if(is_method)
	XPUSHs(sv_2mortal(class));
    else
	SvREFCNT_dec(class);
#else
    SvREFCNT_dec(class);
#endif

    XPUSHs((SV*)perl_bless_request_rec(r)); 

    if(dispatcher) {
	MP_TRACE_h(fprintf(stderr, 
		 "mod_perl: handing off to PerlDispatchHandler `%s'\n", 
			 dispatcher));
        /*XPUSHs(sv_mortalcopy(sv));*/
	XPUSHs(sv);
	sv = dispsv;
    }

    {
	I32 i, len = (args ? AvFILL(args) : 0);

	if(args) {
	    EXTEND(sp, len);
	    for(i=0; i<=len; i++)
		PUSHs(sv_2mortal(*av_fetch(args, i, FALSE)));
	}
    }
    PUTBACK;
    
    /* use G_EVAL so we can trap errors */
#ifdef PERL_METHOD_HANDLERS
    if(is_method)
	count = perl_call_method(method, G_EVAL | G_SCALAR);
    else
#endif
	count = perl_call_sv(sv, G_EVAL | G_SCALAR);
    
    SPAGAIN;

    if(perl_eval_ok(r->server) != OK) {
	MP_STORE_ERROR(r->uri, ERRSV);
	if(!perl_sv_is_http_code(ERRSV, &status))
	    status = SERVER_ERROR;
#if MODULE_MAGIC_NUMBER >= MMN_130
	if(!SvREFCNT(TOPs)) {
#ifdef WIN32
	    mod_perl_error(r->server,
			   "mod_perl: stack is corrupt, server may need restart\n");
#else
	    mod_perl_error(r->server,
			   "mod_perl: stack is corrupt, exiting process\n");
	    my_setenv("PERL_DESTRUCT_LEVEL", "-1");
	    child_terminate(r);
#endif /*WIN32*/
	}
#endif
    }
    else if(count != 1) {
	mod_perl_error(r->server,
		       "perl_call did not return a status arg, assuming OK");
	status = OK;
    }
    else {
	status = POPi;

	if((status == 1) || (status == 200) || (status > 600)) 
	    status = OK; 

	if((status == SERVER_ERROR) && ERRSV_CAN_BE_HTTP) {
	    SV *errsv = Nullsv;
	    if(MP_EXISTS_ERROR(r->uri) && (errsv = MP_FETCH_ERROR(r->uri))) {
		(void)perl_sv_is_http_code(errsv, &status);
	    }
	}
    }

    PUTBACK;
    FREETMPS;
    LEAVE;
    MP_TRACE_g(fprintf(stderr, "perl_call_handler: SVs = %5d, OBJs = %5d\n", 
	    (int)sv_count, (int)sv_objcount));

    if(SvMAGICAL(ERRSV))
       sv_unmagic(ERRSV, 'U'); /* Apache::exit was called */

    return status;
}

request_rec *perl_request_rec(request_rec *r)
{
    if(r != NULL) {
	mp_request_rec = (IV)r;
	return NULL;
    }
    else
	return (request_rec *)mp_request_rec;
}

SV *perl_bless_request_rec(request_rec *r)
{
    SV *sv = sv_newmortal();
    sv_setref_pv(sv, "Apache", (void*)r);
    MP_TRACE_g(fprintf(stderr, "blessing request_rec=(0x%lx)\n",
		     (unsigned long)r));
    return sv;
}

void perl_setup_env(request_rec *r)
{ 
    int i;
    array_header *arr = perl_cgi_env_init(r);
    table_entry *elts = (table_entry *)arr->elts;

    for (i = 0; i < arr->nelts; ++i) {
	if (!elts[i].key || !elts[i].val) continue;
	mp_setenv(elts[i].key, elts[i].val);
    }
    MP_TRACE_g(fprintf(stderr, "perl_setup_env...%d keys\n", i));
}

int mod_perl_seqno(SV *self, int inc)
{
    self = self; /*avoid warning*/
    if(inc) seqno += inc;
    return seqno;
}

