/* ====================================================================
 * Copyright (c) 1995-1997 The Apache Group.  All rights reserved.
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

extern module *top_module;

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
	table_entry *elts = (table_entry *)cld->env->elts;
	int i;
	HV *env = PerlEnvHV; 
	for (i = 0; i < cld->env->nelts; ++i) {
	    MP_TRACE(fprintf(stderr, "mod_perl_dir_env: %s=`%s'",
			     elts[i].key, elts[i].val));
	    hv_store(env, elts[i].key, strlen(elts[i].key), 
		     newSVpv(elts[i].val,0), FALSE); 
	    my_setenv(elts[i].key, elts[i].val);
	}
	MP_HASENV_off(cld); /* just doit once per-request */
    }
}

void mod_perl_pass_env(pool *p, perl_server_config *cls)
{
    char *key, *val;
    CHAR_P arg;

    if(!cls->PerlPassEnv) return;

    arg = pstrdup(p, cls->PerlPassEnv);

    while (*arg) {
        key = getword(p, &arg, ' ');
        val = getenv(key);
        if(val != NULL) {
	    MP_TRACE(fprintf(stderr, "PerlPassEnv: `%s'=`%s'\n", key, val));
	    hv_store(GvHV(envgv), key, strlen(key), 
		     newSVpv(val,0), 0);
        }
    }
}    

void *perl_merge_dir_config (pool *p, void *basev, void *addv)
{
    perl_dir_config *new = (perl_dir_config *)pcalloc (p, sizeof(perl_dir_config));
    perl_dir_config *base = (perl_dir_config *)basev;
    perl_dir_config *add = (perl_dir_config *)addv;

    new->vars = overlay_tables(p, add->vars, base->vars);
    new->env = overlay_tables(p, add->env, base->env);

    /* merge flags */
    MP_FMERGE(new,add,base,MPf_INCPUSH);
    MP_FMERGE(new,add,base,MPf_HASENV);
    MP_FMERGE(new,add,base,MPf_ENV);
    MP_FMERGE(new,add,base,MPf_SENDHDR);
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

    cld->vars = make_table(p, MAX_PERL_CONF_VARS); 
    cld->env  = make_table(p, MAX_PERL_CONF_VARS); 
    cld->flags = MPf_ENV;
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
    perl_server_config *cls =
	(perl_server_config *)palloc(p, sizeof (perl_server_config));

    cls->PerlPassEnv = NULL;
    cls->PerlModules = (char **)NULL; 
    cls->PerlModules = (char **)palloc(p, (MAX_PERL_MODS+1)*sizeof(char *));
    cls->PerlModules[0] = "Apache";
    cls->NumPerlModules = 1;
    cls->PerlScript = (char **)palloc(p, (MAX_PERL_MODS+1)*sizeof(char *));
    cls->NumPerlScript = 0;
    cls->PerlTaintCheck = 0;
    cls->PerlWarn = 0;
    cls->FreshRestart = 0;
    PERL_POST_READ_REQUEST_CREATE(cls);
    PERL_TRANS_CREATE(cls);
    PERL_CHILD_INIT_CREATE(cls);
    PERL_CHILD_EXIT_CREATE(cls);
    return (void *)cls;
}

#ifdef PERL_STACKED_HANDLERS

CHAR_P perl_cmd_push_handlers(char *hook, PERL_CMD_TYPE **cmd, char *arg)
{ 
    SV *sva;
#if !defined(APACHE_SSL) && !defined(WIN32)
    if(!PERL_RUNNING()) { 
        MP_TRACE(fprintf(stderr, "perl_cmd_push_handlers: perl not running, skipping push\n")); 
	return NULL; 
    } 
#endif
    sva = newSVpv(arg,0); 
    if(!*cmd) { 
        *cmd = newAV(); 
	MP_TRACE(fprintf(stderr, "init `%s' stack\n", hook)); 
    } 
    MP_TRACE(fprintf(stderr, "perl_cmd_push_handlers: @%s, '%s'\n", hook, arg)); 
    mod_perl_push_handlers(&sv_yes, hook, sva, *cmd); 
    SvREFCNT_dec(sva); 
    return NULL; 
}

#define PERL_CMD_PUSH_HANDLERS(hook, cmd) \
return perl_cmd_push_handlers(hook,&cmd,arg)

#else

#define PERL_CMD_PUSH_HANDLERS(hook, cmd) \
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
    MP_TRACE(fprintf(stderr, "perl_cmd: PerlDispatchHandler=`%s'\n", arg));
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
    PERL_CMD_PUSH_HANDLERS("PerlHandler", rec->PerlHandler);
}

CHAR_P perl_cmd_log_handlers (cmd_parms *parms, perl_dir_config *rec, char *arg)
{
    PERL_CMD_PUSH_HANDLERS("PerlLogHandler", rec->PerlLogHandler);
}

CHAR_P perl_cmd_init_handlers (cmd_parms *parms, perl_dir_config *rec, char *arg)
{
    PERL_CMD_PUSH_HANDLERS("PerlInitHandler", rec->PerlInitHandler);
}

CHAR_P perl_cmd_cleanup_handlers (cmd_parms *parms, perl_dir_config *rec, char *arg)
{
    PERL_CMD_PUSH_HANDLERS("PerlCleanupHandler", rec->PerlCleanupHandler);
}

CHAR_P perl_cmd_module (cmd_parms *parms, void *dummy, char *arg)
{
    dPSRV(parms->server);

    if(PERL_RUNNING()) 
	perl_require_module(arg, parms->server);
    else {
	MP_TRACE(fprintf(stderr, "push_perl_modules: arg='%s'\n", arg));
	if (cls->NumPerlModules >= MAX_PERL_MODS) {
	    fprintf(stderr, "mod_perl: There's a limit of %d PerlModules, use a PerlScript to pull in as many as you want\n", MAX_PERL_MODS);
	    exit(-1);
	}
	
	cls->PerlModules[cls->NumPerlModules++] = arg;
    }
    return NULL;
}

#define NO_PERL_SCRIPT (strnEQ(SvPVX(perl_get_sv("0",FALSE)), "-e", 2))  

CHAR_P perl_cmd_script (cmd_parms *parms, void *dummy, char *arg)
{
    dPSRV(parms->server);
    MP_TRACE(fprintf(stderr, "perl_cmd_script: %s\n", arg));
    if(PERL_RUNNING()) 
	perl_load_startup_script(parms->server, parms->pool, arg, TRUE);
    else {
	if (cls->NumPerlScript >= MAX_PERL_MODS) {
	    fprintf(stderr, "mod_perl: There's a limit of %d PerlScripts\n",
		    MAX_PERL_MODS);
	    exit(-1);
	}
	
	cls->PerlScript[cls->NumPerlScript++] = arg;
    }
    return NULL;
}

CHAR_P perl_cmd_tainting (cmd_parms *parms, void *dummy, int arg)
{
    dPSRV(parms->server);
    MP_TRACE(fprintf(stderr, "perl_cmd_tainting: %d\n", arg));
    cls->PerlTaintCheck = arg;
#ifdef PERL_SECTIONS
    if(arg && PERL_RUNNING()) tainting = TRUE;
#endif
    return NULL;
}

CHAR_P perl_cmd_warn (cmd_parms *parms, void *dummy, int arg)
{
    dPSRV(parms->server);
    MP_TRACE(fprintf(stderr, "perl_cmd_warn: %d\n", arg));
    cls->PerlWarn = arg;
#ifdef PERL_SECTIONS
    if(arg && PERL_RUNNING()) dowarn = TRUE;
#endif
    return NULL;
}

CHAR_P perl_cmd_fresh_restart (cmd_parms *parms, void *dummy, int arg)
{
    dPSRV(parms->server);
    MP_TRACE(fprintf(stderr, "perl_cmd_fresh_restart: %d\n", arg));
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
    cls->PerlPassEnv = pstrcat(parms->pool, arg, " ", 
			       cls->PerlPassEnv, NULL);
    arg = NULL;
    return NULL;
}
  
CHAR_P perl_cmd_env (cmd_parms *cmd, perl_dir_config *rec, int arg) {
    if(arg) MP_ENV_on(rec);
    else	   MP_ENV_off(rec);
    MP_TRACE(fprintf(stderr, "perl_cmd_env: set to `%s'\n", arg ? "On" : "Off"));
    return NULL;
}

CHAR_P perl_cmd_var(cmd_parms *cmd, perl_dir_config *rec, char *key, char *val)
{
    table_set(rec->vars, key, val);
    MP_TRACE(fprintf(stderr, "perl_cmd_var: '%s' = '%s'\n", key, val));
    return NULL;
}

CHAR_P perl_cmd_setenv(cmd_parms *cmd, perl_dir_config *rec, char *key, char *val)
{
    table_set(rec->env, key, val);
    MP_HASENV_on(rec);
    MP_TRACE(fprintf(stderr, "perl_cmd_setenv: '%s' = '%s'\n", key, val));
    return NULL;
}

#ifdef PERL_SECTIONS
#if MODULE_MAGIC_NUMBER < 19970719
#define limit_section limit
#endif

/* some prototypes for -Wall sake */
const char *handle_command (cmd_parms *parms, void *config, const char *l);
const char *limit_section (cmd_parms *cmd, void *dummy, const char *arg);
void add_per_dir_conf (server_rec *s, void *dir_config);
void add_per_url_conf (server_rec *s, void *url_config);
void add_file_conf (core_dir_config *conf, void *url_config);
const command_rec *find_command_in_modules (const char *cmd_name, module **mod);

#if MODULE_MAGIC_NUMBER > 19970912 
#define cmd_infile parms->config_file

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
#define cmd_infile parms->infile
#define STRING_MEAL(s) 0
#define perl_eat_config_string(cmd, dummy, sv)
#endif

CHAR_P perl_srm_command_loop(cmd_parms *parms, SV *sv)
{
    char l[MAX_STRING_LEN];
    if(PERL_RUNNING()) {
	sv_catpvn(sv, "\npackage ApacheReadConfig;\n{\n", 29);
	sv_catpvn(sv, "\n", 1);
    }
    while (!(cfg_getline (l, MAX_STRING_LEN, cmd_infile))) {
	if(instr(l, "</Perl>"))
	    break;
	if(PERL_RUNNING()) {
	    sv_catpv(sv, l);
	    sv_catpvn(sv, "\n", 1);
	}
    }
    if(PERL_RUNNING())
	sv_catpvn(sv, "\n}\n", 3);
    return NULL;
}

#define dSEC \
    const char *key; \
    I32 klen; \
    SV *val

#define dSECiter_start \
    (void)hv_iterinit(hv); \
    while ((val = hv_iternextsv(hv, (char **) &key, &klen))) { \
	HV *tab; \
	if(SvMAGICAL(val)) mg_get(val); \
	if((tab = (HV *)SvRV(val))) { 

#define dSECiter_stop \
        } \
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
	MP_TRACE(fprintf(stderr, "%s (%s) Limit=%s\n", 
			 line, 
			 (errmsg ? errmsg : "OK"),
			 (cmd->limited > 0 ? "yes" : "no") ));
    }
} 

#define TRACE_SECTION(n,v) \
    MP_TRACE(fprintf(stderr, "perl_section: <%s %s>\n", n, v))

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

    return NULL;
}

#if MODULE_MAGIC_NUMBER > 19970719 /* 1.3a1 */
#include "fnmatch.h"
#define test__is_match(conf) conf->d_is_fnmatch = is_fnmatch( conf->d ) != 0
#else
#define test__is_match(conf) conf->d_is_matchexp = is_matchexp( conf->d )
#endif

CHAR_P perl_urlsection (cmd_parms *cmd, void *dummy, HV *hv)
{
    dSEC;
    int old_overrides = cmd->override;
    char *old_path = cmd->path;

    dSECiter_start

    core_dir_config *conf;
    regex_t *r = NULL;

    void *new_url_conf = create_per_dir_config (cmd->pool);
    
    cmd->path = pstrdup(cmd->pool, getword_conf (cmd->pool, &key));
    cmd->override = OR_ALL|ACCESS_CONF;

    if (!strcmp(cmd->path, "~")) {
	cmd->path = getword_conf (cmd->pool, &key);
	r = pregcomp(cmd->pool, cmd->path, REG_EXTENDED);
    }

    TRACE_SECTION("Location", cmd->path);

    /* XXX, why must we??? */
    if(!hv_exists(tab, "Options", 7)) 
	hv_store(tab, "Options", 7, 
		 newSVpv("Indexes FollowSymLinks",22), 0);

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

    /* XXX, why must we??? */
    if(!hv_exists(tab, "Options", 7)) 
	hv_store(tab, "Options", 7, 
		 newSVpv("Indexes FollowSymLinks",22), 0);

    perl_section_hash_walk(cmd, new_dir_conf, tab);

    conf = (core_dir_config *)get_module_config(new_dir_conf, &core_module);
    conf->r = r;

    add_per_dir_conf (cmd->server, new_dir_conf);

    dSECiter_stop

    cmd->path = old_path;
    cmd->override = old_overrides;

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

    /* XXX, why must we??? */
    if(!hv_exists(tab, "Options", 7)) 
	hv_store(tab, "Options", 7, 
		 newSVpv("Indexes FollowSymLinks",22), 0);

    perl_section_hash_walk(cmd, new_file_conf, tab);

    conf = (core_dir_config *)get_module_config(new_file_conf, &core_module);
    if(!conf->opts)
	conf->opts = OPT_NONE;
    conf->d = pstrdup(cmd->pool, cmd->path);
    test__is_match(conf);
    conf->r = r;

    perl_add_file_conf (cmd->server, new_file_conf);

    dSECiter_stop

    cmd->path = old_path;
    cmd->override = old_overrides;

    return NULL;
}

CHAR_P perl_limit_section(cmd_parms *cmd, void *dummy, HV *hv)
{
    SV *sv = hv_delete(hv, "METHODS", 7, G_SCALAR);
    STRLEN len;
    char *methods = sv ? SvPV(sv,len) : ""; 
    /*void *ac = (void*)create_default_per_dir_config(cmd->pool);*/
    
    if(!sv) return NULL;

    MP_TRACE(fprintf(stderr, 
		     "Found Limit section for `%s'\n", methods));

    limit_section(cmd, dummy, methods); 
    perl_section_hash_walk(cmd, dummy, hv);
    cmd->limited = -1;

    return NULL;
}

static const char perl_end_magic[] = "</Perl> outside of any <Perl> section";

CHAR_P perl_end_section (cmd_parms *cmd, void *dummy) {
    return perl_end_magic;
}

void perl_handle_command(cmd_parms *cmd, void *dummy, char *line) 
{
    CHAR_P errmsg;
    errmsg = handle_command(cmd, dummy, line);
    MP_TRACE(fprintf(stderr, "handle_command (%s): %s\n", line, 
		     (errmsg ? errmsg : "OK")));
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
    GV *gv = GvHV_init(name);
    if(dotie) perl_tie_hash(GvHV(gv), "Tie::IxHash");
}

CHAR_P perl_section (cmd_parms *cmd, void *dummy, const char *arg)
{
    dTHR;
    CHAR_P errmsg;
    SV *code = newSV(0), *val;
    HV *symtab;
    char *key;
    I32 klen, dotie=FALSE;
    char line[MAX_STRING_LEN];

    if(!PERL_RUNNING()) perl_startup(cmd->server, cmd->pool); 

    sv_setpv(code, "");
    errmsg = perl_srm_command_loop(cmd, code);

    if(!PERL_RUNNING()) {
	MP_TRACE(fprintf(stderr, "perl_section: Perl not running, returning...\n"));
	SvREFCNT_dec(code);
	return NULL;
    }

    if((perl_require_module("Tie::IxHash", NULL) == OK))
	dotie = TRUE;

    perl_section_hash_init("ApacheReadConfig::Location", dotie);
    perl_section_hash_init("ApacheReadConfig::VirtualHost", dotie);
    perl_section_hash_init("ApacheReadConfig::Directory", dotie);
    perl_section_hash_init("ApacheReadConfig::Files", dotie);
    perl_section_hash_init("ApacheReadConfig::Limit", dotie);

    perl_eval_sv(code, G_DISCARD);
    if(SvTRUE(ERRSV)) {
       fprintf(stderr, "Apache::ReadConfig: %s\n", SvPV(ERRSV,na));
       return NULL;
    }

    symtab = (HV*)gv_stashpv("ApacheReadConfig", FALSE);
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
		    perl_eat_config_string(cmd, dummy, sv);
		}
		else {
		    MP_TRACE(fprintf(stderr, "SVt_PV: $%s = `%s'\n", 
				     key, SvPV(sv,na)));
		    sprintf(line, "%s %s", key, SvPV(sv,na));
		    perl_handle_command(cmd, dummy, line);
		}
	    }
	}

	if((hv = GvHV((GV*)val))) {
	    perl_handle_command_hv(hv, key, cmd, dummy);
	}
	else if((av = GvAV((GV*)val))) {	
	    module *mod = top_module;
	    const command_rec *c; 
	    I32 shift, alen = AvFILL(av);

	    if(STRING_MEAL(key)) {
		SV *tmpsv;
		while((tmpsv = av_shift(av)) != &sv_undef)
		    perl_eat_config_string(cmd, dummy, tmpsv);
		continue;
	    }

	    if(!(c = find_command_in_modules((const char *)key, &mod))) {
		fprintf(stderr, "command_rec for directive `%s' not found!\n", key);
		continue;
	    }

	    MP_TRACE(fprintf(stderr, 
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
		MP_TRACE(fprintf(stderr, 
				 "default: iterating over @%s\n", key));
		shift = 1;
		break;
	    }
	    if(shift > alen) shift = 1; /* elements are refs */ 
	    perl_handle_command_av(av, shift, key, cmd, dummy);
	}
    }
    SvREFCNT_dec(code);
    hv_undef(symtab);
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
#if MODULE_MAGIC_NUMBER >= 19970728
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
#endif /* MMN */
	    if (strEQ(name, "Cleanup")) 
#ifdef PERL_CLEANUP
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

