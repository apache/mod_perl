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

#define CORE_PRIVATE 
#include "mod_perl.h"

extern API_VAR_EXPORT module *top_module;

#ifdef PERL_SECTIONS
static int perl_sections_self_boot = 0;
static const char *perl_sections_boot_module = NULL;

#if MODULE_MAGIC_NUMBER < 19970719
#define limit_section limit
#endif

/* some prototypes for -Wall and win32 sake */
#if MODULE_MAGIC_NUMBER >= 19980317
extern API_VAR_EXPORT module core_module;
#else
API_EXPORT(const char *) handle_command (cmd_parms *parms, void *config, const char *l);
API_EXPORT(const char *) limit_section (cmd_parms *cmd, void *dummy, const char *arg);
API_EXPORT(void) add_per_dir_conf (server_rec *s, void *dir_config);
API_EXPORT(void) add_per_url_conf (server_rec *s, void *url_config);
API_EXPORT(const command_rec *) find_command (const char *name, const command_rec *cmds);
API_EXPORT(const command_rec *) find_command_in_modules (const char *cmd_name, module **mod);
#endif

#if MODULE_MAGIC_NUMBER > 19970912 

void perl_config_getstr(void *buf, size_t bufsiz, void *param)
{
    SV *sv = (SV*)param;
    STRLEN len;
    char *tmp = SvPV(sv,len);

    if(!SvTRUE(sv)) 
	return;

    Move(tmp, buf, bufsiz, char);

    if(len < bufsiz) {
	sv_setpv(sv, "");
    }
    else {
	tmp += bufsiz;
	sv_setpv(sv, tmp);
    }
}

int perl_config_getch(void *param)
{
    SV *sv = (SV*)param;
    STRLEN len;
    char *tmp = SvPV(sv,len);
    register int retval = *tmp;

    if(!SvTRUE(sv)) 
	return EOF;

    if(len <= 1) {
	sv_setpv(sv, "");
    }
    else {
	++tmp;
	sv_setpv(sv, tmp);
    }

    return retval;
}

void perl_eat_config_string(cmd_parms *cmd, void *dummy, SV *sv) {
    CHAR_P errmsg; 
    configfile_t *perl_cfg = 
	pcfg_open_custom(cmd->pool, "mod_perl", (void*)sv,
			 perl_config_getch, NULL, NULL);

    configfile_t *old_cfg = cmd->config_file;
    cmd->config_file = perl_cfg;
    errmsg = srm_command_loop(cmd, dummy);
    cmd->config_file = old_cfg;

    if(errmsg)
	fprintf(stderr, "mod_perl: %s\n", errmsg);
}

#define STRING_MEAL(s) ( (*s == 'P') && strEQ(s,"PerlConfig") )
#else
#define STRING_MEAL(s) 0
#define perl_eat_config_string(cmd, dummy, sv) 
#endif

#define PERL_SECTIONS_PACKAGE "ApacheReadConfig"

#endif /* PERL_SECTIONS */

char *mod_perl_auth_name(request_rec *r, char *val)
{
#ifndef WIN32 
    core_dir_config *conf = 
      (core_dir_config *)get_module_config(r->per_dir_config, &core_module); 

    if(val) {
	conf->auth_name = pstrdup(r->pool, val);
	set_module_config(r->per_dir_config, &core_module, (void*)conf); 
	MP_TRACE(fprintf(stderr, "mod_perl: setting auth_name to %s\n", conf->auth_name));
    }

    return conf->auth_name;
#else
    return auth_name(r);
#endif
}

void mod_perl_dir_env(perl_dir_config *cld)
{
    if(MP_HASENV(cld)) {
	array_header *arr = table_elts(cld->env);
	table_entry *elts = (table_entry *)arr->elts;

	int i;
	for (i = 0; i < arr->nelts; ++i) {
	    MP_TRACE_d(fprintf(stderr, "mod_perl_dir_env: %s=`%s'",
			     elts[i].key, elts[i].val));
	    mp_setenv(elts[i].key, elts[i].val);
	}
	MP_HASENV_off(cld); /* just doit once per-request */
    }
}

void mod_perl_pass_env(pool *p, perl_server_config *cls)
{
    char *key, *val, **keys;
    int i;

    if(!cls->PerlPassEnv->nelts) return;

    keys = (char **)cls->PerlPassEnv->elts;
    for (i = 0; i < cls->PerlPassEnv->nelts; ++i) {
	key = keys[i];

        if(!(val = getenv(key)) && (ind(key, ':') > 0)) {
	    CHAR_P tmp = pstrdup(p, key);
	    key = getword(p, &tmp, ':');
	    val = (char *)tmp;
	}

        if(val != NULL) {
	    MP_TRACE_d(fprintf(stderr, "PerlPassEnv: `%s'=`%s'\n", key, val));
	    mp_SetEnv(key,val);
        }
    }
}    

void *perl_merge_dir_config (pool *p, void *basev, void *addv)
{
    perl_dir_config *new = (perl_dir_config *)pcalloc (p, sizeof(perl_dir_config));
    perl_dir_config *base = (perl_dir_config *)basev;
    perl_dir_config *add = (perl_dir_config *)addv;

    array_header *vars = (array_header *)base->vars;

    new->location = add->location ? 
        add->location : base->location;

    /* XXX: what triggers such a condition ?*/
    if(vars && (vars->nelts > 100000)) {
	fprintf(stderr, "[warning] PerlSetVar->nelts = %d\n", vars->nelts);
    }
    else {
	new->vars = overlay_tables(p, add->vars, base->vars);
    }

    new->vars = overlay_tables(p, add->vars, base->vars);
    new->env = overlay_tables(p, add->env, base->env);

    new->SendHeader = (add->SendHeader != MPf_None) ?
	add->SendHeader : base->SendHeader;

    new->SetupEnv = (add->SetupEnv != MPf_None) ?
	add->SetupEnv : base->SetupEnv;

    /* merge flags */
    MP_FMERGE(new,add,base,MPf_INCPUSH);
    MP_FMERGE(new,add,base,MPf_HASENV);
    /*MP_FMERGE(new,add,base,MPf_ENV);*/
    /*MP_FMERGE(new,add,base,MPf_SENDHDR);*/
    MP_FMERGE(new,add,base,MPf_SENTHDR);
    MP_FMERGE(new,add,base,MPf_CLEANUP);
    MP_FMERGE(new,add,base,MPf_RCLEANUP);

#ifdef PERL_DISPATCH
    new->PerlDispatchHandler = add->PerlDispatchHandler ? 
        add->PerlDispatchHandler : base->PerlDispatchHandler;
#endif
#ifdef PERL_INIT
    new->PerlInitHandler = add->PerlInitHandler ? 
        add->PerlInitHandler : base->PerlInitHandler;
#endif
#ifdef PERL_HEADER_PARSER
    new->PerlHeaderParserHandler = add->PerlHeaderParserHandler ? 
        add->PerlHeaderParserHandler : base->PerlHeaderParserHandler;
#endif
#ifdef PERL_ACCESS
    new->PerlAccessHandler = add->PerlAccessHandler ? 
        add->PerlAccessHandler : base->PerlAccessHandler;
#endif
#ifdef PERL_AUTHEN
    new->PerlAuthenHandler = add->PerlAuthenHandler ? 
        add->PerlAuthenHandler : base->PerlAuthenHandler;
#endif
#ifdef PERL_AUTHZ
    new->PerlAuthzHandler = add->PerlAuthzHandler ? 
        add->PerlAuthzHandler : base->PerlAuthzHandler;
#endif
#ifdef PERL_TYPE
    new->PerlTypeHandler = add->PerlTypeHandler ? 
        add->PerlTypeHandler : base->PerlTypeHandler;
#endif
#ifdef PERL_FIXUP
    new->PerlFixupHandler = add->PerlFixupHandler ? 
        add->PerlFixupHandler : base->PerlFixupHandler;
#endif
#if 1
    new->PerlHandler = add->PerlHandler ? add->PerlHandler : base->PerlHandler;
#endif
#ifdef PERL_LOG
    new->PerlLogHandler = add->PerlLogHandler ? 
        add->PerlLogHandler : base->PerlLogHandler;
#endif
#ifdef PERL_CLEANUP
    new->PerlCleanupHandler = add->PerlCleanupHandler ? 
        add->PerlCleanupHandler : base->PerlCleanupHandler;
#endif

    return new;
}

void *perl_create_dir_config (pool *p, char *dirname)
{
    perl_dir_config *cld =
	(perl_dir_config *)palloc(p, sizeof (perl_dir_config));

    cld->location = pstrdup(p, dirname);
    cld->vars = make_table(p, 5); 
    cld->env  = make_table(p, 5); 
    cld->flags = MPf_ENV;
    cld->SendHeader = MPf_None;
    cld->SetupEnv = MPf_On;
    cld->PerlHandler = PERL_CMD_INIT;
    PERL_DISPATCH_CREATE(cld);
    PERL_AUTHEN_CREATE(cld);
    PERL_AUTHZ_CREATE(cld);
    PERL_ACCESS_CREATE(cld);
    PERL_TYPE_CREATE(cld);
    PERL_FIXUP_CREATE(cld);
    PERL_LOG_CREATE(cld);
    PERL_CLEANUP_CREATE(cld);
    PERL_HEADER_PARSER_CREATE(cld);
    PERL_INIT_CREATE(cld);
    return (void *)cld;
}

void *perl_create_server_config (pool *p, server_rec *s)
{
    char **new;
    perl_server_config *cls =
	(perl_server_config *)palloc(p, sizeof (perl_server_config));

    cls->PerlPassEnv = make_array(p, 1, sizeof(char *));
    cls->PerlModule  = make_array(p, 1, sizeof(char *));
    cls->PerlRequire = make_array(p, 1, sizeof(char *));
    cls->PerlTaintCheck = 0;
    cls->PerlWarn = 0;
    cls->FreshRestart = 0;
    cls->PerlOpmask = NULL;
    PERL_POST_READ_REQUEST_CREATE(cls);
    PERL_TRANS_CREATE(cls);
    PERL_CHILD_INIT_CREATE(cls);
    PERL_CHILD_EXIT_CREATE(cls);
    PERL_RESTART_CREATE(cls);
    PERL_INIT_CREATE(cls);

    return (void *)cls;
}

perl_request_config *perl_create_request_config(pool *p, server_rec *s)
{
    perl_request_config *cfg = 
	(perl_request_config *)pcalloc(p, sizeof(perl_request_config));
    cfg->pnotes = Nullhv;
    return cfg;
}

#ifdef WIN32
#define mp_preload_module(name)
#else
static void mp_preload_module(char **name)
{
    if(ind(*name, ' ') >= 0) return;
    if(**name == '-' && ++*name) return;
    if(**name == '+') ++*name;
    else if(!PERL_AUTOPRELOAD) return;
    if(!PERL_RUNNING()) return;

    if(!perl_module_is_loaded(*name)) { 
	MP_TRACE_d(fprintf(stderr, 
			   "mod_perl: attempting to pre-load module `%s'\n", 
			   *name));
	perl_require_module(*name,NULL);
    }
}
#endif

#ifdef PERL_STACKED_HANDLERS

CHAR_P perl_cmd_push_handlers(char *hook, PERL_CMD_TYPE **cmd, char *arg, pool *p)
{ 
    SV *sva;
    mp_preload_module(&arg);
    sva = newSVpv(arg,0); 
    if(!*cmd) { 
        *cmd = newAV(); 
	register_cleanup(p, (void*)*cmd, mod_perl_cleanup_av, mod_perl_noop);
	MP_TRACE_d(fprintf(stderr, "init `%s' stack\n", hook)); 
    } 
    MP_TRACE_d(fprintf(stderr, "perl_cmd_push_handlers: @%s, '%s'\n", hook, arg)); 
    mod_perl_push_handlers(&sv_yes, hook, sva, *cmd); 
    SvREFCNT_dec(sva); 
    return NULL; 
}

#define PERL_CMD_PUSH_HANDLERS(hook, cmd) \
if(!PERL_RUNNING()) { \
    perl_startup(parms->server, parms->pool); \
    require_Apache(parms->server); \
    MP_TRACE_g(fprintf(stderr, "mod_perl: %s calling perl_startup()\n", __FUNCTION__)); \
} \
return perl_cmd_push_handlers(hook,&cmd,arg,parms->pool)

#else

#define PERL_CMD_PUSH_HANDLERS(hook, cmd) \
mp_preload_module(&arg); \
cmd = arg; \
return NULL

int mod_perl_push_handlers(SV *self, char *hook, SV *sub, AV *handlers)
{
    warn("Rebuild with -DPERL_STACKED_HANDLERS to $r->push_handlers");
    return 0;
}

#endif

CHAR_P perl_cmd_dispatch_handlers (cmd_parms *parms, perl_dir_config *rec, char *arg)
{
    rec->PerlDispatchHandler = pstrdup(parms->pool, arg);
    MP_TRACE_d(fprintf(stderr, "perl_cmd: PerlDispatchHandler=`%s'\n", arg));
    return NULL;
}

CHAR_P perl_cmd_child_init_handlers (cmd_parms *parms, void *dummy, char *arg)
{
    dPSRV(parms->server);
    PERL_CMD_PUSH_HANDLERS("PerlChildInitHandler", cls->PerlChildInitHandler);
}

CHAR_P perl_cmd_child_exit_handlers (cmd_parms *parms, void *dummy, char *arg)
{
    dPSRV(parms->server);
    PERL_CMD_PUSH_HANDLERS("PerlChildExitHandler", cls->PerlChildExitHandler);
}

CHAR_P perl_cmd_restart_handlers (cmd_parms *parms, void *dummy, char *arg)
{
    dPSRV(parms->server);
    PERL_CMD_PUSH_HANDLERS("PerlRestartHandler", cls->PerlRestartHandler);
}

CHAR_P perl_cmd_post_read_request_handlers (cmd_parms *parms, void *dummy, char *arg)
{
    dPSRV(parms->server);
    PERL_CMD_PUSH_HANDLERS("PerlPostReadRequestHandler", cls->PerlPostReadRequestHandler);
}

CHAR_P perl_cmd_trans_handlers (cmd_parms *parms, void *dummy, char *arg)
{
    dPSRV(parms->server);
    PERL_CMD_PUSH_HANDLERS("PerlTransHandler", cls->PerlTransHandler);
}

CHAR_P perl_cmd_header_parser_handlers (cmd_parms *parms, perl_dir_config *rec, char *arg)
{
    PERL_CMD_PUSH_HANDLERS("PerlHeaderParserHandler", rec->PerlHeaderParserHandler);
}

CHAR_P perl_cmd_access_handlers (cmd_parms *parms, perl_dir_config *rec, char *arg)
{
    PERL_CMD_PUSH_HANDLERS("PerlAccessHandler", rec->PerlAccessHandler);
}

CHAR_P perl_cmd_authen_handlers (cmd_parms *parms, perl_dir_config *rec, char *arg)
{
    PERL_CMD_PUSH_HANDLERS("PerlAuthenHandler", rec->PerlAuthenHandler);
}

CHAR_P perl_cmd_authz_handlers (cmd_parms *parms, perl_dir_config *rec, char *arg)
{
    PERL_CMD_PUSH_HANDLERS("PerlAuthzHandler", rec->PerlAuthzHandler);
}

CHAR_P perl_cmd_type_handlers (cmd_parms *parms, perl_dir_config *rec, char *arg)
{
    PERL_CMD_PUSH_HANDLERS("PerlTypeHandler",  rec->PerlTypeHandler);
}

CHAR_P perl_cmd_fixup_handlers (cmd_parms *parms, perl_dir_config *rec, char *arg)
{
    PERL_CMD_PUSH_HANDLERS("PerlFixupHandler", rec->PerlFixupHandler);
}

CHAR_P perl_cmd_handler_handlers (cmd_parms *parms, perl_dir_config *rec, char *arg)
{
#if 0
    /* would be nice if this worked, but it just doesn't "stick" */
    handle_command(parms, (void*)rec, "SetHandler perl-script");
#endif
    PERL_CMD_PUSH_HANDLERS("PerlHandler", rec->PerlHandler);
}

CHAR_P perl_cmd_log_handlers (cmd_parms *parms, perl_dir_config *rec, char *arg)
{
    PERL_CMD_PUSH_HANDLERS("PerlLogHandler", rec->PerlLogHandler);
}

CHAR_P perl_cmd_init_handlers (cmd_parms *parms, void *rec, char *arg)
{
    dPSRV(parms->server);
    if(parms->path) {
	PERL_CMD_PUSH_HANDLERS("PerlInitHandler", 
			       ((perl_dir_config *)rec)->PerlInitHandler);
    }
    else {
	PERL_CMD_PUSH_HANDLERS("PerlInitHandler", cls->PerlInitHandler);
    }
}

CHAR_P perl_cmd_cleanup_handlers (cmd_parms *parms, perl_dir_config *rec, char *arg)
{
    PERL_CMD_PUSH_HANDLERS("PerlCleanupHandler", rec->PerlCleanupHandler);
}

CHAR_P perl_cmd_module (cmd_parms *parms, void *dummy, char *arg)
{
    dPSRV(parms->server);
    if(!PERL_RUNNING()) perl_startup(parms->server, parms->pool); 
    require_Apache(parms->server);
    if(PERL_RUNNING()) 
	perl_require_module(arg, parms->server);
    else {
	char **new;
	MP_TRACE_d(fprintf(stderr, "push_perl_modules: arg='%s'\n", arg));
	new = (char **)push_array(cls->PerlModule);
	*new = pstrdup(parms->pool, arg);
    }

#ifdef PERL_SECTIONS
    if((parms->path == NULL) && PERL_SECTIONS_SELF_BOOT)
	perl_section_self_boot(parms, dummy, arg);
#endif

    return NULL;
}

CHAR_P perl_cmd_require (cmd_parms *parms, void *dummy, char *arg)
{
    dPSRV(parms->server);
    if(!PERL_RUNNING()) perl_startup(parms->server, parms->pool); 
    MP_TRACE_d(fprintf(stderr, "perl_cmd_require: %s\n", arg));
    if(PERL_RUNNING()) 
	perl_load_startup_script(parms->server, parms->pool, arg, TRUE);
    else {
	char **new;
	new = (char **)push_array(cls->PerlRequire);
	*new = pstrdup(parms->pool, arg);
    }

#ifdef PERL_SECTIONS
    if((parms->path == NULL) && PERL_SECTIONS_SELF_BOOT)
	perl_section_self_boot(parms, dummy, arg);
#endif

    return NULL;
}

#ifdef PERL_SAFE_STARTUP
CHAR_P perl_cmd_opmask (cmd_parms *parms, void *dummy, char *arg)
{
    dPSRV(parms->server);
    MP_TRACE_d(fprintf(stderr, "perl_cmd_opmask: %s\n", arg));
    cls->PerlOpmask = arg;
#ifdef PERL_DEFAULT_MASK
    return "Default Opmask is on, cannot re-configure";
#else
    return NULL;
#endif
}
#endif

void perl_tainting_set(server_rec *s, int arg)
{
    dPSRV(s);
    GV *gv;

    cls->PerlTaintCheck = arg;
    if(PERL_RUNNING()) {
	gv = GvSV_init("Apache::__T");
	if(arg) {
	    SvREADONLY_off(GvSV(gv));
	    GvSV_setiv(gv, TRUE);
	    SvREADONLY_on(GvSV(gv));
	    tainting = TRUE;
	}
    }
}

CHAR_P perl_cmd_tainting (cmd_parms *parms, void *dummy, int arg)
{
    MP_TRACE_d(fprintf(stderr, "perl_cmd_tainting: %d\n", arg));
    perl_tainting_set(parms->server, arg);
    return NULL;
}

CHAR_P perl_cmd_warn (cmd_parms *parms, void *dummy, int arg)
{
    dPSRV(parms->server);
    MP_TRACE_d(fprintf(stderr, "perl_cmd_warn: %d\n", arg));
    cls->PerlWarn = arg;
#ifdef PERL_SECTIONS
    if(arg && PERL_RUNNING()) dowarn = TRUE;
#endif
    return NULL;
}

CHAR_P perl_cmd_fresh_restart (cmd_parms *parms, void *dummy, int arg)
{
    dPSRV(parms->server);
    MP_TRACE_d(fprintf(stderr, "perl_cmd_fresh_restart: %d\n", arg));
    cls->FreshRestart = arg;
    return NULL;
}

CHAR_P perl_cmd_sendheader (cmd_parms *cmd,  perl_dir_config *rec, int arg) {
    if(arg)
	MP_SENDHDR_on(rec);
    else
	MP_SENDHDR_off(rec);
    MP_SENTHDR_on(rec);
    return NULL;
}

CHAR_P perl_cmd_pass_env (cmd_parms *parms, void *dummy, char *arg)
{
    dPSRV(parms->server);
    if(PERL_RUNNING()) {
	mp_PassEnv(arg);
    }
    else {
	char **new;
	new = (char **)push_array(cls->PerlPassEnv);
	*new = pstrdup(parms->pool, arg);
    }
    MP_TRACE_d(fprintf(stderr, "perl_cmd_pass_env: arg=`%s'\n", arg));
    arg = NULL;
    return NULL;
}
  
CHAR_P perl_cmd_env (cmd_parms *cmd, perl_dir_config *rec, int arg) {
    if(arg) MP_ENV_on(rec);
    else	   MP_ENV_off(rec);
    MP_TRACE_d(fprintf(stderr, "perl_cmd_env: set to `%s'\n", arg ? "On" : "Off"));
    return NULL;
}

CHAR_P perl_cmd_var(cmd_parms *cmd, perl_dir_config *rec, char *key, char *val)
{
    table_set(rec->vars, key, val);
    MP_TRACE_d(fprintf(stderr, "perl_cmd_var: '%s' = '%s'\n", key, val));
    return NULL;
}

CHAR_P perl_cmd_setenv(cmd_parms *cmd, perl_dir_config *rec, char *key, char *val)
{
    table_set(rec->env, key, val);
    MP_HASENV_on(rec);
    MP_TRACE_d(fprintf(stderr, "perl_cmd_setenv: '%s' = '%s'\n", key, val));
    if(cmd->path == NULL) {
	if(PERL_RUNNING()) { 
	    mp_SetEnv(key,val);
	} 
	else { 
           char **new; 
           dPSRV(cmd->server); 
           new = (char **)push_array(cls->PerlPassEnv); 
           *new = pstrcat(cmd->pool, key, ":", val, NULL); 
	} 
    }
    return NULL;
}

CHAR_P perl_config_END (cmd_parms *parms, void *dummy, const char *arg)
{
    char l[MAX_STRING_LEN];

    while (!(cfg_getline (l, MAX_STRING_LEN, cmd_infile))) {
	/* soak up the of the file */
    }

    return NULL;   
}

#if 0
#define APACHE_POD_FORMAT(s) \
 (strnEQ(s, "httpd", 5) || strnEQ(s, "apache", 6))

CHAR_P perl_pod_section (cmd_parms *parms, void *dummy, const char *arg)
{
    char l[MAX_STRING_LEN];

    if(arg && strlen(arg) && !APACHE_POD_FORMAT(arg)) 
	return "Unknown =end format";

    while (!(cfg_getline (l, MAX_STRING_LEN, cmd_infile))) {
	int chop = 4;
	if(strnEQ(l, "=cut", 4))
	    break;
	if(strnEQ(l, "=for", chop) || 
	   ((chop = 6) && strnEQ(l, "=begin", chop)))
	{
	    char *tmp = l;
	    tmp += chop; while(isspace(*tmp)) tmp++;
	    if(APACHE_POD_FORMAT(tmp))
		break;
	}
    }

    return NULL;   
}
#else
#define APACHE_POD_FORMAT(s) \
 (strstr(s, "httpd") || strstr(s, "apache"))

CHAR_P perl_pod_section (cmd_parms *parms, void *dummy, const char *arg)
{
    char line[MAX_STRING_LEN];

    if(arg && strlen(arg) && !(APACHE_POD_FORMAT(arg) || strstr(arg, "pod"))) 
	return "Unknown =back format";

    while (!(cfg_getline (line, sizeof(line), cmd_infile))) {
	if(strnEQ(line, "=cut", 4))
	    break;
	if(strnEQ(line, "=over", 5)) {
	    if(APACHE_POD_FORMAT(line)) 
		break;
	}
    }

    return NULL;   
}
#endif

static const char perl_pod_end_magic[] = "=cut without =pod";

CHAR_P perl_pod_end_section (cmd_parms *cmd, void *dummy) {
    return NULL;
}

void mod_perl_cleanup_av(void *data)
{
    AV *av = (AV*)data;
    if(SvREFCNT((SV*)av)) {
	MP_TRACE_g(fprintf(stderr, "cleanup_av: SvREFCNT(0x%lx)==%d\n", 
			   (unsigned long)av, (int)SvREFCNT((SV*)av)));
	SvREFCNT_dec((SV*)av);
    }
}

#ifdef PERL_DIRECTIVE_HANDLERS

CHAR_P perl_cmd_perl_TAKE1(cmd_parms *cmd, mod_perl_perl_dir_config *data, char *one)
{
    return perl_cmd_perl_TAKE123(cmd, data, one, NULL, NULL);
}

CHAR_P perl_cmd_perl_TAKE2(cmd_parms *cmd, mod_perl_perl_dir_config *data, char *one, char *two)
{
    return perl_cmd_perl_TAKE123(cmd, data, one, two, NULL);
}

CHAR_P perl_cmd_perl_FLAG(cmd_parms *cmd, mod_perl_perl_dir_config *data, int flag)
{
    char buf[2];
    ap_snprintf(buf, sizeof(buf), "%d", flag);
    return perl_cmd_perl_TAKE123(cmd, data, buf, NULL, NULL);
}

static SV *perl_bless_cmd_parms(cmd_parms *parms)
{
    SV *sv = sv_newmortal();
    sv_setref_pv(sv, "Apache::CmdParms", (void*)parms);
    MP_TRACE_g(fprintf(stderr, "blessing cmd_parms=(0x%lx)\n",
		     (unsigned long)parms));
    return sv;
}

module *perl_get_module_ptr(char *name, int len)
{
    HV *xs_config = perl_get_hv("Apache::XS_ModuleConfig", TRUE);
    SV **mod_ptr = hv_fetch(xs_config, name, len, FALSE);
    if(mod_ptr && *mod_ptr)
	return (module *)SvIV((SV*)SvRV(*mod_ptr));
    else
	return NULL;
}

static SV *
perl_perl_create_cfg(SV **sv, HV *class, cmd_parms *parms, char *type)
{
    GV *gv;

    if(*sv && SvTRUE(*sv) && SvROK(*sv) && sv_isobject(*sv))
	return *sv;

    /* return $class->type if $class->can(type) */
    if((gv = gv_fetchmethod_autoload(class, type, FALSE)) && isGV(gv)) {
	int count;
	dSP;

	ENTER;SAVETMPS;
	PUSHMARK(sp);
	XPUSHs(sv_2mortal(newSVpv(HvNAME(class),0)));
	if(parms)
	    XPUSHs(perl_bless_cmd_parms(parms));
	PUTBACK;
	count = perl_call_sv((SV*)GvCV(gv), G_EVAL | G_SCALAR);
	SPAGAIN;
	if((perl_eval_ok(parms ? parms->server : NULL) == OK) && (count == 1)) {
	    *sv = POPs;
	    ++SvREFCNT(*sv);
	}
	PUTBACK;
	FREETMPS;LEAVE;

	return *sv;
    }
    else {
	/* return bless {}, $class */
	if(!SvTRUE(*sv)) {
	    *sv = newRV_noinc((SV*)newHV());
	    return sv_bless(*sv, class);
	}
	else
	    return *sv;
    }
}

static SV *perl_perl_create_dir_config(SV **sv, HV *class, cmd_parms *parms)
{
    return perl_perl_create_cfg(sv, class, parms, PERL_DIR_CREATE);
}

static SV *perl_perl_create_srv_config(SV **sv, HV *class, cmd_parms *parms)
{
    return perl_perl_create_cfg(sv, class, parms, PERL_SERVER_CREATE);
}

static void *perl_perl_merge_cfg(pool *p, void *basev, void *addv, char *meth)
{
    GV *gv;
    mod_perl_perl_dir_config *new = NULL,
	*basevp = (mod_perl_perl_dir_config *)basev,
	*addvp  = (mod_perl_perl_dir_config *)addv;

    SV *sv, 
	*basesv = basevp ? basevp->obj : Nullsv,
	*addsv  = addvp  ? addvp->obj  : Nullsv;

    if(!basesv) basesv = addsv;
    if(!sv_isobject(basesv))
	return basesv;

    MP_TRACE_c(fprintf(stderr, "looking for method %s in package `%s'\n", 
		       meth, SvCLASS(basesv)));

    if((gv = gv_fetchmethod_autoload(SvSTASH(SvRV(basesv)), meth, FALSE)) && isGV(gv)) {
	int count;
	dSP;
	new = (mod_perl_perl_dir_config *)
	    palloc(p, sizeof(mod_perl_perl_dir_config));

	MP_TRACE_c(fprintf(stderr, "calling %s->%s\n", 
			   SvCLASS(basesv), meth));

	ENTER;SAVETMPS;
	PUSHMARK(sp);
	XPUSHs(basesv);XPUSHs(addsv);
	PUTBACK;
	count = perl_call_sv((SV*)GvCV(gv), G_EVAL | G_SCALAR);
	SPAGAIN;
	if((perl_eval_ok(NULL) == OK) && (count == 1)) {
	    sv = POPs;
	    ++SvREFCNT(sv);
	    new->obj = sv;
	    new->class = SvCLASS(sv);
	}
	PUTBACK;
	FREETMPS;LEAVE;
    }
    else {
	new->obj = newSVsv(basesv);
	new->class = basevp->class;
    }
    return (void *)new;
}

void *perl_perl_merge_dir_config(pool *p, void *basev, void *addv)
{
    return perl_perl_merge_cfg(p, basev, addv, PERL_DIR_MERGE);
}

void *perl_perl_merge_srv_config(pool *p, void *basev, void *addv)
{
    return perl_perl_merge_cfg(p, basev, addv, PERL_SERVER_MERGE);
}

void perl_perl_cmd_cleanup(void *data)
{
    mod_perl_perl_dir_config *cld = (mod_perl_perl_dir_config *)data;

    if(cld->obj) {
	MP_TRACE_c(fprintf(stderr, 
			   "cmd_cleanup: SvREFCNT($%s::$obj) == %d\n",
			   cld->class, (int)SvREFCNT(cld->obj)));
	SvREFCNT_dec(cld->obj);
    }
}

CHAR_P perl_cmd_perl_TAKE123(cmd_parms *cmd, mod_perl_perl_dir_config *data,
				  char *one, char *two, char *three)
{
    dSP;
    mod_perl_cmd_info *info = (mod_perl_cmd_info *)cmd->info;
    char *subname = info->subname, *retval = NULL;
    int count = 0;
    CV *cv = perl_get_cv(subname, TRUE);
    SV *obj;
    bool has_empty_proto = (SvPOK(cv) && (SvLEN(cv) == 1));
    module *xsmod = perl_get_module_ptr(data->class, strlen(data->class));
    mod_perl_perl_dir_config *sdata = NULL;
    obj = perl_perl_create_dir_config(&data->obj, CvSTASH(cv), cmd);

    if(xsmod && 
       (sdata = get_module_config(cmd->server->module_config, xsmod))) {
	(void)perl_perl_create_srv_config(&sdata->obj, CvSTASH(cv), cmd);
	set_module_config(cmd->server->module_config, xsmod, sdata);
    }

    ENTER;SAVETMPS;
    PUSHMARK(sp);
    if(!has_empty_proto) {
	SV *cmd_obj = perl_bless_cmd_parms(cmd);
	XPUSHs(obj);
	XPUSHs(cmd_obj);
	if(cmd->cmd->args_how != NO_ARGS) {
	    PUSHif(one);PUSHif(two);PUSHif(three);
	}
	if(SvPOK(cv) && (*(SvEND((SV*)cv)-1) == '*')) {
	    SV *gp = mod_perl_gensym("Apache::CmdParms");
	    sv_magic((SV*)SvRV(gp), cmd_obj, 'q', Nullch, 0); 
	    XPUSHs(gp);
	}
    }
    PUTBACK;
    count = perl_call_sv((SV*)cv, G_EVAL | G_SCALAR);
    SPAGAIN;
    if(count == 1) {
	if(strEQ(POPp, DECLINE_CMD))
	    retval = DECLINE_CMD;
	PUTBACK;
    }
    FREETMPS;LEAVE;

    if(SvTRUE(ERRSV))
	retval = SvPVX(ERRSV);

    return retval;
}
#endif /* PERL_DIRECTIVE_HANDLERS */

#ifdef PERL_SECTIONS

CHAR_P perl_srm_command_loop(cmd_parms *parms, SV *sv)
{
    char l[MAX_STRING_LEN];

    if(PERL_RUNNING()) {
	sv_catpvf(sv, "package %s;", PERL_SECTIONS_PACKAGE);
	sv_catpvf(sv, "\n\n#line %d %s\n", cmd_linenum+1, cmd_filename);
    }

    while (!(cfg_getline (l, MAX_STRING_LEN, cmd_infile))) {
	if(strncasecmp(l, "</Perl>", 7) == 0)
	    break;
	if(PERL_RUNNING()) {
	    sv_catpv(sv, l);
	    sv_catpvn(sv, "\n", 1);
	}
    }

    return NULL;
}

#define dSEC \
    const char *key; \
    I32 klen; \
    SV *val

#define dSECiter_start \
    (void)hv_iterinit(hv); \
    while ((val = hv_iternextsv(hv, (char **) &key, &klen))) { \
        HV *tab = Nullhv; \
        AV *list = Nullav; \
	if(SvMAGICAL(val)) mg_get(val); \
	if(SvROK(val) && (SvTYPE(SvRV(val)) == SVt_PVHV)) \
	    tab = (HV *)SvRV(val); \
	else if(SvROK(val) && (SvTYPE(SvRV(val)) == SVt_PVAV)) \
	    list = (AV *)SvRV(val); \
	else \
	    croak("value of `%s' is not a HASH or ARRAY reference!", key); \
	if(list || tab) { \

#define dSECiter_stop \
        } \
    }

#define SECiter_list(t) \
{ \
    I32 i; \
    for(i=0; i<=AvFILL(list); i++) { \
        SV *rv = *av_fetch(list, i, FALSE); \
        HV *nhv; \
        if(!SvROK(rv) || (SvTYPE(SvRV(rv)) != SVt_PVHV)) \
   	    croak("not a HASH reference!"); \
        nhv = newHV(); \
        hv_store(nhv, (char*)key, klen, rv, FALSE); \
        tab = nhv; \
        t; \
        SvREFCNT_dec(nhv); \
    } \
    list = Nullav; \
    continue; \
}

void perl_section_hash_walk(cmd_parms *cmd, void *cfg, HV *hv)
{
    CHAR_P errmsg;
    char *tmpkey; 
    I32 tmpklen; 
    SV *tmpval;
    (void)hv_iterinit(hv); 
    while ((tmpval = hv_iternextsv(hv, &tmpkey, &tmpklen))) { 
	char line[MAX_STRING_LEN]; 
	char *value = NULL;
	if(SvROK(tmpval)) {
	    if(SvTYPE(SvRV(tmpval)) == SVt_PVAV) {
		perl_handle_command_av((AV*)SvRV(tmpval), 
				       0, tmpkey, cmd, cfg);
		continue;
	    }
	    else if(SvTYPE(SvRV(tmpval)) == SVt_PVHV) {
		perl_handle_command_hv((HV*)SvRV(tmpval), 
				       tmpkey, cmd, cfg); 
		continue;
	    }
	}
	else
	    value = SvPV(tmpval,na); 

	sprintf(line, "%s %s", tmpkey, value);
	errmsg = handle_command(cmd, cfg, line); 
	MP_TRACE_s(fprintf(stderr, "%s (%s) Limit=%s\n", 
			 line, 
			 (errmsg ? errmsg : "OK"),
			 (cmd->limited > 0 ? "yes" : "no") ));
	if(errmsg)
	    log_printf(cmd->server, "<Perl>: %s", errmsg);
    }
} 

#define TRACE_SECTION(n,v) \
    MP_TRACE_s(fprintf(stderr, "perl_section: <%s %s>\n", n, v))

#define TRACE_SECTION_END(n) \
    MP_TRACE_s(fprintf(stderr, "perl_section: </%s>\n", n))

/* XXX, had to copy-n-paste much code from http_core.c for
 * perl_*sections, would be nice if the core config routines 
 * had a handful of callback hooks instead
 */

CHAR_P perl_virtualhost_section (cmd_parms *cmd, void *dummy, HV *hv)
{
    dSEC;
    server_rec *main_server = cmd->server, *s;
    pool *p = cmd->pool;
    char *arg; 
    const char *errmsg = NULL;
    dSECiter_start

    if(list) {
	SECiter_list(perl_virtualhost_section(cmd, dummy, tab));
    }

    arg = pstrdup(cmd->pool, getword_conf (cmd->pool, &key));

#if MODULE_MAGIC_NUMBER >= 19970912
    errmsg = init_virtual_host(p, arg, main_server, &s);
#else
    s = init_virtual_host(p, arg, main_server);
#endif

    if (errmsg)
	return errmsg;   

    s->next = main_server->next;
    main_server->next = s;
    cmd->server = s;

    TRACE_SECTION("VirtualHost", arg);

    perl_section_hash_walk(cmd, s->lookup_defaults, tab);

    cmd->server = main_server;

    dSECiter_stop
    TRACE_SECTION_END("VirtualHost");
    return NULL;
}

#if MODULE_MAGIC_NUMBER > 19970719 /* 1.3a1 */
#include "fnmatch.h"
#ifdef WIN32
#define test__is_match(conf)
#else
#define test__is_match(conf) conf->d_is_fnmatch = is_fnmatch( conf->d ) != 0
#endif
#else
#define test__is_match(conf) conf->d_is_matchexp = is_matchexp( conf->d )
#endif

/* for some odd reason, of there is no Options directive, we get a core dump.
 * work-around for now is setting it to something "harmless" 
 */
#define ADD_OPTIONS_WA \
    if(!hv_exists(tab, "Options", 7)) \
	hv_store(tab, "Options", 7, newSVpv("+MultiViews",0), 0)

CHAR_P perl_urlsection (cmd_parms *cmd, void *dummy, HV *hv)
{
    dSEC;
    int old_overrides = cmd->override;
    char *old_path = cmd->path;

    dSECiter_start

    core_dir_config *conf;
    regex_t *r = NULL;

    void *new_url_conf = create_per_dir_config (cmd->pool);

    if(list) {
	SECiter_list(perl_urlsection(cmd, dummy, tab));
    }
    
    cmd->path = pstrdup(cmd->pool, getword_conf (cmd->pool, &key));
    cmd->override = OR_ALL|ACCESS_CONF;

    if (!strcmp(cmd->path, "~")) {
	cmd->path = getword_conf (cmd->pool, &key);
	r = pregcomp(cmd->pool, cmd->path, REG_EXTENDED);
    }

    TRACE_SECTION("Location", cmd->path);

    ADD_OPTIONS_WA;

    perl_section_hash_walk(cmd, new_url_conf, tab);

    conf = (core_dir_config *)get_module_config(
	new_url_conf, &core_module);
    if(!conf->opts)
	conf->opts = OPT_NONE;
    conf->d = pstrdup(cmd->pool, cmd->path);
    test__is_match(conf);
    conf->r = r;

    add_per_url_conf (cmd->server, new_url_conf);
	    
    dSECiter_stop

    cmd->path = old_path;
    cmd->override = old_overrides;
    TRACE_SECTION_END("Location");
    return NULL;
}

CHAR_P perl_dirsection (cmd_parms *cmd, void *dummy, HV *hv)
{
    dSEC;
    int old_overrides = cmd->override;
    char *old_path = cmd->path;

    dSECiter_start

    core_dir_config *conf;
    void *new_dir_conf = create_per_dir_config (cmd->pool);
    regex_t *r = NULL;

    if(list) {
	SECiter_list(perl_dirsection(cmd, dummy, tab));
    }

    cmd->path = pstrdup(cmd->pool, getword_conf (cmd->pool, &key));

#ifdef __EMX__
    /* Fix OS/2 HPFS filename case problem. */
    cmd->path = strlwr(cmd->path);
#endif    
    cmd->override = OR_ALL|ACCESS_CONF;

    if (!strcmp(cmd->path, "~")) {
	cmd->path = getword_conf (cmd->pool, &key);
	r = pregcomp(cmd->pool, cmd->path, REG_EXTENDED);
    }

    TRACE_SECTION("Directory", cmd->path);

    ADD_OPTIONS_WA;

    perl_section_hash_walk(cmd, new_dir_conf, tab);

    conf = (core_dir_config *)get_module_config(new_dir_conf, &core_module);
    conf->r = r;

    add_per_dir_conf (cmd->server, new_dir_conf);

    dSECiter_stop

    cmd->path = old_path;
    cmd->override = old_overrides;
    TRACE_SECTION_END("Directory");
    return NULL;
}

void perl_add_file_conf (server_rec *s, void *url_config)
{
    core_server_config *sconf = get_module_config (s->module_config,
						   &core_module);
    void **new_space = (void **) push_array (sconf->sec);
    
    *new_space = url_config;
}

CHAR_P perl_filesection (cmd_parms *cmd, void *dummy, HV *hv)
{
    dSEC;
    int old_overrides = cmd->override;
    char *old_path = cmd->path;

    dSECiter_start

    core_dir_config *conf;
    void *new_file_conf = create_per_dir_config (cmd->pool);
    regex_t *r = NULL;

    if(list) {
	SECiter_list(perl_filesection(cmd, dummy, tab));
    }

    cmd->path = pstrdup(cmd->pool, getword_conf (cmd->pool, &key));
    /* Only if not an .htaccess file */
    if (cmd->path)
	cmd->override = OR_ALL|ACCESS_CONF;

    if (!strcmp(cmd->path, "~")) {
	cmd->path = getword_conf (cmd->pool, &key);
	if (old_path && cmd->path[0] != '/' && cmd->path[0] != '^')
	    cmd->path = pstrcat(cmd->pool, "^", old_path, cmd->path, NULL);
	r = pregcomp(cmd->pool, cmd->path, REG_EXTENDED);
    }
    else if (old_path && cmd->path[0] != '/')
	cmd->path = pstrcat(cmd->pool, old_path, cmd->path, NULL);

    TRACE_SECTION("Files", cmd->path);

    ADD_OPTIONS_WA;

    perl_section_hash_walk(cmd, new_file_conf, tab);

    conf = (core_dir_config *)get_module_config(new_file_conf, &core_module);
    if(!conf->opts)
	conf->opts = OPT_NONE;
    conf->d = pstrdup(cmd->pool, cmd->path);
    test__is_match(conf);
    conf->r = r;

    perl_add_file_conf (cmd->server, new_file_conf);

    dSECiter_stop
    TRACE_SECTION_END("Files");
    cmd->path = old_path;
    cmd->override = old_overrides;

    return NULL;
}

CHAR_P perl_limit_section(cmd_parms *cmd, void *dummy, HV *hv)
{
    SV *sv;
    char *methods;
    /*void *ac = (void*)create_default_per_dir_config(cmd->pool);*/

    if(hv_exists(hv,"METHODS", 7))
       sv = hv_delete(hv, "METHODS", 7, G_SCALAR);
    else
	return NULL;

    methods = SvPOK(sv) ? SvPVX(sv) : "";
 
    MP_TRACE_s(fprintf(stderr, 
		     "Found Limit section for `%s'\n", 
		     methods ? methods : "all methods"));

    limit_section(cmd, dummy, methods); 
    perl_section_hash_walk(cmd, dummy, hv);
    cmd->limited = -1;

    return NULL;
}

static const char perl_end_magic[] = "</Perl> outside of any <Perl> section";

CHAR_P perl_end_section (cmd_parms *cmd, void *dummy) {
    return perl_end_magic;
}

int perl_handle_self_command(cmd_parms *parms, void *dummy, char *line)
{
    const command_rec *cmd;
    const char *cmd_name, *args;

    if(!perl_sections_self_boot || (parms->path != NULL))
	return FALSE;

    args = line;

    cmd_name = getword_conf(parms->temp_pool, &args);

    if (*cmd_name == '\0')
	return FALSE;

    if(!(cmd = find_command(cmd_name, perl_module.cmds))) {
	/*fprintf(stderr, "%s is not a mod_perl command\n", cmd_name);*/
	return FALSE;
    }
    else {
	if(cmd->req_override == OR_ALL) {
	    if(perl_sections_self_boot && perl_sections_boot_module) {
		fprintf(stderr, "Error in PerlModule %s\n", 
			perl_sections_boot_module);
		fprintf(stderr, 
			"*Apache::ReadConfig::%s must be inside a container\n", 
			cmd_name);
	    }
	    else {
		fprintf(stderr, "Error in <Perl> section:\n");
		fprintf(stderr, "*%s must be inside a container\n", 
		    cmd_name);
	    }

	    exit(1);
	    return TRUE;
	}
    }

    return FALSE;
}

void perl_handle_command(cmd_parms *cmd, void *dummy, char *line) 
{
    CHAR_P errmsg;

    if(perl_handle_self_command(cmd, dummy, line))
	return;
    MP_TRACE_s(fprintf(stderr, "handle_command (%s): ", line));
    errmsg = handle_command(cmd, dummy, line);
    MP_TRACE_s(fprintf(stderr, "%s\n", errmsg ? errmsg : "OK"));
    if(errmsg)
	log_printf(cmd->server, "<Perl>: %s", errmsg);
}

void perl_handle_command_hv(HV *hv, char *key, cmd_parms *cmd, void *dummy)
{
    if(strEQ(key, "Location")) 	
	perl_urlsection(cmd, dummy, hv);
    else if(strEQ(key, "Directory")) 
	perl_dirsection(cmd, dummy, hv);
    else if(strEQ(key, "VirtualHost")) 
	perl_virtualhost_section(cmd, dummy, hv);
    else if(strEQ(key, "Files")) 
	perl_filesection(cmd, (core_dir_config *)dummy, hv);
    else if(strEQ(key, "Limit")) 
	perl_limit_section(cmd, dummy, hv);
}

void perl_handle_command_av(AV *av, I32 n, char *key, cmd_parms *cmd, void *dummy)
{
    I32 alen = AvFILL(av);
    I32 i, j;
    I32 oldwarn = dowarn; /*XXX, hmm*/
    dowarn = FALSE;

    if(!n) n = alen+1;

    for(i=0; i<=alen; i+=n) {
	SV *fsv;
	if(AvFILL(av) < 0)
	    break;

	fsv = *av_fetch(av, 0, FALSE);

	if(SvROK(fsv)) {
	    i -= n;
	    perl_handle_command_av((AV*)SvRV(av_shift(av)), 0, 
				   key, cmd, dummy);
	}
	else {
	    SV *sv = newSV(0);
	    sv_catpv(sv, key);
	    sv_catpvn(sv, " ", 1);

	    for(j=1; j<=n; j++) {
		sv_catsv(sv, av_shift(av));
		if(j != n)
		    sv_catpvn(sv, " ", 1);
	    }

	    perl_handle_command(cmd, dummy, SvPVX(sv));
	    SvREFCNT_dec(sv);
	}
    }
    dowarn = oldwarn; 
}

#ifdef PERL_TRACE
char *splain_args(enum cmd_how args_how) {
    switch(args_how) {
    case RAW_ARGS:
	return "RAW_ARGS";
    case TAKE1:
	return "TAKE1";
    case TAKE2:
	return "TAKE2";
    case ITERATE:
	return "ITERATE";
    case ITERATE2:
	return "ITERATE2";
    case FLAG:
	return "FLAG";
    case NO_ARGS:
	return "NO_ARGS";
    case TAKE12:
	return "TAKE12";
    case TAKE3:
	return "TAKE3";
    case TAKE23:
	return "TAKE23";
    case TAKE123:
	return "TAKE123";
    case TAKE13:
	return "TAKE13";
    default:
	return "__UNKNOWN__";
    };
}
#endif

void perl_section_hash_init(char *name, I32 dotie)
{
    dTHR;
    GV *gv;
    ENTER;
    save_hptr(&curstash);
    curstash = gv_stashpv(PERL_SECTIONS_PACKAGE, GV_ADDWARN);
    gv = GvHV_init(name);
    if(dotie && !perl_sections_self_boot)
	perl_tie_hash(GvHV(gv), "Tie::IxHash", Nullsv);
    LEAVE;
}

void perl_section_self_boot(cmd_parms *parms, void *dummy, const char *arg)
{
    HV *symtab;
    if(!PERL_RUNNING()) perl_startup(parms->server, parms->pool); 

    if(!(symtab = gv_stashpv(PERL_SECTIONS_PACKAGE, FALSE))) 
	return;

    if(HvKEYS(symtab) < 1) 
	return;
    if(!defined_Apache__ReadConfig)
	return;

    MP_TRACE_s(fprintf(stderr, 
		     "bootstrapping <Perl> sections: arg=%s, keys=%d\n", 
		       arg, (int)HvKEYS(symtab)));
    
    perl_sections_boot_module = arg;
    perl_sections_self_boot = 1;
    perl_section(parms, dummy, NULL);
    perl_sections_self_boot = 0;
    perl_sections_boot_module = NULL;

    /* make sure this module is re-loaded for the second config read */
    if(PERL_RUNNING() == 1) {
	SV *file = Nullsv;
	if(arg) {
	    if(strrchr(arg, '/') || strrchr(arg, '.'))
		file = newSVpv((char *)arg,0);
	    else
		file = perl_module2file((char *)arg);
	}

	if(file && hv_exists_ent(GvHV(incgv), file, FALSE)) {
	    MP_TRACE_s(fprintf(stderr,
			     "mod_perl: delete $INC{'%s'} (klen=%d)\n", 
			     SvPVX(file), SvCUR(file)));
	    (void)hv_delete_ent(GvHV(incgv), file, G_DISCARD, FALSE);
	}
	if(file)
	    SvREFCNT_dec(file);
    }   
}

static void clear_symtab(HV *symtab) 
{
    SV *val;
    char *key;
    I32 klen;

    (void)hv_iterinit(symtab);
    while ((val = hv_iternextsv(symtab, &key, &klen))) {
	SV *sv;
	HV *hv;
	AV *av;

	if((SvTYPE(val) != SVt_PVGV) || GvIMPORTED((GV*)val))
	    continue;
	if((sv = GvSV((GV*)val)))
	    sv_setsv(GvSV((GV*)val), &sv_undef);
	if((hv = GvHV((GV*)val)))
	    hv_clear(hv);
	if((av = GvAV((GV*)val)))
	    av_clear(av);
    }
}

CHAR_P perl_section (cmd_parms *parms, void *dummy, const char *arg)
{
    CHAR_P errmsg;
    SV *code, *val;
    HV *symtab;
    char *key;
    I32 klen, dotie=FALSE;
    char line[MAX_STRING_LEN];

    if(!PERL_RUNNING()) perl_startup(parms->server, parms->pool); 
    require_Apache(parms->server);

    if(PERL_RUNNING()) {
	code = newSV(0);
	sv_setpv(code, "");
	if(arg) 
	    errmsg = perl_srm_command_loop(parms, code);
    }
    else {
	MP_TRACE_s(fprintf(stderr, 
			 "perl_section: Perl not running, returning...\n"));
	return NULL;
    }

    if((perl_require_module("Tie::IxHash", NULL) == OK))
	dotie = TRUE;

    perl_section_hash_init("Location", dotie);
    perl_section_hash_init("LocationMatch", dotie);
    perl_section_hash_init("VirtualHost", dotie);
    perl_section_hash_init("Directory", dotie);
    perl_section_hash_init("DirectoryMatch", dotie);
    perl_section_hash_init("Files", dotie);
    perl_section_hash_init("FilesMatch", dotie);
    perl_section_hash_init("Limit", dotie);

    sv_setpv(perl_get_sv("0", TRUE), cmd_filename);

    ENTER_SAFE(parms->server, parms->pool);
    MP_TRACE_g(mod_perl_dump_opmask());
    perl_eval_sv(code, G_DISCARD);
    LEAVE_SAFE;

    {
	dTHR;
	if(SvTRUE(ERRSV)) {
	    MP_TRACE_s(fprintf(stderr, 
			       "Apache::ReadConfig: %s\n", SvPV(ERRSV,na)));
	    return SvPV(ERRSV,na);
	}
    }

    symtab = (HV*)gv_stashpv(PERL_SECTIONS_PACKAGE, FALSE);
    (void)hv_iterinit(symtab);
    while ((val = hv_iternextsv(symtab, &key, &klen))) {
	SV *sv;
	HV *hv;
	AV *av;

	if(SvTYPE(val) != SVt_PVGV) 
	    continue;

	if((sv = GvSV((GV*)val))) {
	    if(SvTRUE(sv)) {
		if(STRING_MEAL(key)) {
		    perl_eat_config_string(parms, dummy, sv);
		}
		else {
		    MP_TRACE_s(fprintf(stderr, "SVt_PV: $%s = `%s'\n", 
				     key, SvPV(sv,na)));
		    sprintf(line, "%s %s", key, SvPV(sv,na));
		    perl_handle_command(parms, dummy, line);
		}
	    }
	}

	if((hv = GvHV((GV*)val))) {
	    perl_handle_command_hv(hv, key, parms, dummy);
	}
	else if((av = GvAV((GV*)val))) {	
	    module *mod = top_module;
	    const command_rec *c; 
	    I32 shift, alen = AvFILL(av);

	    if(STRING_MEAL(key)) {
		SV *tmpsv;
		while((tmpsv = av_shift(av)) != &sv_undef)
		    perl_eat_config_string(parms, dummy, tmpsv);
		continue;
	    }

	    if(!(c = find_command_in_modules((const char *)key, &mod))) {
		fprintf(stderr, "command_rec for directive `%s' not found!\n", key);
		continue;
	    }

	    MP_TRACE_s(fprintf(stderr, 
			     "`@%s' directive is %s, (%d elements)\n", 
			     key, splain_args(c->args_how), AvFILL(av)+1));

	    switch (c->args_how) {
		
	    case TAKE23:
	    case TAKE2:
		shift = 2;
		break;

	    case TAKE3:
		shift = 3;
		break;

	    default:
		MP_TRACE_s(fprintf(stderr, 
				 "default: iterating over @%s\n", key));
		shift = 1;
		break;
	    }
	    if(shift > alen) shift = 1; /* elements are refs */ 
	    perl_handle_command_av(av, shift, key, parms, dummy);
	}
    }
    SvREFCNT_dec(code);
    {
	SV *usv = perl_get_sv("Apache::Server::SaveConfig", FALSE);
	if(usv && SvTRUE(usv))
	    ; /* keep it around */
	else
	    clear_symtab(symtab);
    }
    return NULL;
}

#endif /* PERL_SECTIONS */

int perl_hook(char *name)
{
    switch (*name) {
	case 'A':
	    if (strEQ(name, "Authen")) 
#ifdef PERL_AUTHEN
		return 1;
#else
	return 0;    
#endif
	if (strEQ(name, "Authz"))
#ifdef PERL_AUTHZ
	    return 1;
#else
	return 0;    
#endif
	if (strEQ(name, "Access"))
#ifdef PERL_ACCESS
	    return 1;
#else
	return 0;    
#endif
	break;
	case 'C':
	    if (strEQ(name, "ChildInit")) 
#ifdef PERL_CHILD_INIT
		return 1;
#else
	return 0;    
#endif
	    if (strEQ(name, "ChildExit")) 
#ifdef PERL_CHILD_EXIT
		return 1;
#else
	return 0;    
#endif
	    if (strEQ(name, "Cleanup")) 
#ifdef PERL_CLEANUP
		return 1;
#else
	return 0;    
#endif
	break;
	case 'D':
	    if (strEQ(name, "Dispatch")) 
#ifdef PERL_DISPATCH
		return 1;
#else
	return 0;    
#endif
	break;
	case 'F':
	    if (strEQ(name, "Fixup")) 
#ifdef PERL_FIXUP
		return 1;
#else
	return 0;    
#endif
	break;
#if MODULE_MAGIC_NUMBER >= 19970103
	case 'H':
	    if (strEQ(name, "HeaderParser")) 
#ifdef PERL_HEADER_PARSER
		return 1;
#else
	return 0;    
#endif
	break;
#endif
#if MODULE_MAGIC_NUMBER >= 19970103
	case 'I':
	    if (strEQ(name, "Init")) 
#ifdef PERL_INIT
		return 1;
#else
	return 0;    
#endif
	break;
#endif
	case 'L':
	    if (strEQ(name, "Log")) 
#ifdef PERL_LOG
		return 1;
#else
	return 0;    
#endif
	break;
	case 'M':
	    if (strEQ(name, "MethodHandlers")) 
#ifdef PERL_METHOD_HANDLERS
		return 1;
#else
	return 0;    
#endif
	break;
	case 'P':
	    if (strEQ(name, "PostReadRequest")) 
#ifdef PERL_POST_READ_REQUEST
		return 1;
#else
	return 0;    
#endif
	break;
	case 'S':
	    if (strEQ(name, "SSI")) 
#ifdef PERL_SSI
		return 1;
#else
	return 0;    
#endif
	    if (strEQ(name, "StackedHandlers")) 
#ifdef PERL_STACKED_HANDLERS
		return 1;
#else
	return 0;    
#endif
	    if (strEQ(name, "Sections")) 
#ifdef PERL_SECTIONS
		return 1;
#else
	return 0;    
#endif
	break;
	case 'T':
	    if (strEQ(name, "Trans")) 
#ifdef PERL_TRANS
		return 1;
#else
	return 0;    
#endif
        if (strEQ(name, "Type")) 
#ifdef PERL_TYPE
	    return 1;
#else
	return 0;    
#endif
	break;
    }
    return -1;
}

