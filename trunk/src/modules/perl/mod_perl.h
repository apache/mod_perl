#ifdef WIN32
#define NO_PERL_SECTIONS
#define NO_PERL_CHILD_INIT
#define NO_PERL_CHILD_EXIT
#include "dirent.h"
#endif

#ifdef USE_THREADS
#define _INCLUDE_APACHE_FIRST
#endif

#ifdef _INCLUDE_APACHE_FIRST
#include "httpd.h" 
#include "http_config.h" 
#include "http_protocol.h" 
#include "http_log.h" 
#include "http_main.h" 
#include "http_core.h" 
#include "http_request.h" 
#include "util_script.h" 
#include "http_conf_globals.h"
#endif

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifndef MOD_PERL_VERSION
#define MOD_PERL_VERSION "TRUE"
#endif

/* perl hides it's symbols in libperl when these macros are 
 * expanded to Perl_foo
 * but some cause conflict when expanded in other headers files
 */
#undef S_ISREG
#undef DIR
#undef VOIDUSED
#undef pregexec
#undef pregfree
#undef pregcomp
#undef setregid
#undef setreuid
#undef sync
#undef my_memcmp
#undef RETURN
#undef die

#ifndef _INCLUDE_APACHE_FIRST
#include "httpd.h" 
#include "http_config.h" 
#include "http_protocol.h" 
#include "http_log.h" 
#include "http_main.h" 
#include "http_core.h" 
#include "http_request.h" 
#include "util_script.h" 
#include "http_conf_globals.h"
#endif

#ifndef dTHR
#define dTHR extern int errno
#endif

#ifndef ERRSV
#define ERRSV GvSV(errgv) 
#endif

typedef request_rec * Apache;
typedef request_rec * Apache__SubRequest;
typedef conn_rec    * Apache__Connection;
typedef server_rec  * Apache__Server;

#define GvHV_init(gv) gv_fetchpv(gv, GV_ADDMULTI, SVt_PVHV)

#define iniHV(hv) hv = (HV*)sv_2mortal((SV*)newHV())
#define iniAV(av) av = (AV*)sv_2mortal((SV*)newAV())

#define AvTRUE(av) (av && (AvFILL(av) > -1) && SvREFCNT(av))

#define av_copy_array(av) av_make(av_len(av)+1, AvARRAY(av))  

#define PerlEnvHV GvHV(envgv)

#ifndef newRV_noinc
#define newRV_noinc(sv)	((Sv = newRV(sv)), --SvREFCNT(SvRV(Sv)), Sv)
#endif

#ifndef SvTAINTED_on
#define SvTAINTED_on(sv) if (tainting) sv_magic(sv, Nullsv, 't', Nullch, 0)
#endif

#define HV_SvTAINTED_on(hv,key,klen) \
    SvTAINTED_on(*hv_fetch(hv, key, klen, 0)) 

#ifdef PERL_TRACE
#define MP_TRACE(a) a 
#else
#define MP_TRACE(a)
#endif

/* cut down on some noise in source */
#define dSTATUS int status = DECLINED

#define dPPDIR \
   perl_dir_config *cld = get_module_config(r->per_dir_config, &perl_module)   

#define dPSRV(srv) \
   perl_server_config *cls = get_module_config (srv->module_config, &perl_module)

/* per-directory flags */

#define MPf_INCPUSH	0x00000100 /* use lib split ":", $ENV{PERL5LIB} */
#define MPf_SENDHDR	0x00000200 /* is PerlSendHeader On? */
#define MPf_SENTHDR	0x00000400 /* has PerlSendHeader sent the headers? */
#define MPf_ENV		0x00000800 /* PerlSetupEnv */
#define MPf_HASENV	0x00001000 /* do we have any PerlSetEnv's? */
#define MPf_DSTDERR	0x00002000 /* redirect stderr to error_log */
#define MPf_CLEANUP	0x00004000 /* did we register our cleanup ? */
#define MPf_RCLEANUP	0x00008000 /* for $r->register_cleanup */

#define MP_FMERGE(new,add,base,f) \
if((add->flags & f) || (base->flags & f)) \
    new->flags |= f
    
#define MP_INCPUSH(d)    (d->flags & MPf_INCPUSH)
#define MP_INCPUSH_on(d)  (d->flags |= MPf_INCPUSH)
#define MP_INCPUSH_off(d)  (d->flags  &= ~MPf_INCPUSH)

#define MP_SENDHDR(d)    (d->flags & MPf_SENDHDR)
#define MP_SENDHDR_on(d)  (d->flags |= MPf_SENDHDR)
#define MP_SENDHDR_off(d)  (d->flags  &= ~MPf_SENDHDR)

#define MP_SENTHDR(d)    (d->flags & MPf_SENTHDR)
#define MP_SENTHDR_on(d)  (d->flags |= MPf_SENTHDR)
#define MP_SENTHDR_off(d)  (d->flags  &= ~MPf_SENTHDR)

#define MP_ENV(d)       (d->flags & MPf_ENV)
#define MP_ENV_on(d)     (d->flags |= MPf_ENV)
#define MP_ENV_off(d)    (d->flags  &= ~MPf_ENV)

#define MP_HASENV(d)    (d->flags & MPf_HASENV)
#define MP_HASENV_on(d)  (d->flags |= MPf_HASENV)
#define MP_HASENV_off(d)  (d->flags  &= ~MPf_HASENV)

#define MP_DSTDERR(d)    (d->flags & MPf_DSTDERR)
#define MP_DSTDERR_on(d)  (d->flags |= MPf_DSTDERR)
#define MP_DSTDERR_off(d)  (d->flags  &= ~MPf_DSTDERR)

#define MP_CLEANUP(d)    (d->flags & MPf_CLEANUP)
#define MP_CLEANUP_on(d)  (d->flags |= MPf_CLEANUP)
#define MP_CLEANUP_off(d)  (d->flags  &= ~MPf_CLEANUP)

#define MP_RCLEANUP(d)    (d->flags & MPf_RCLEANUP)
#define MP_RCLEANUP_on(d)  (d->flags |= MPf_RCLEANUP)
#define MP_RCLEANUP_off(d)  (d->flags  &= ~MPf_RCLEANUP)

#define PERL_GATEWAY_INTERFACE "CGI-Perl/1.1"
/* Apache::SSI */
#define PERL_APACHE_SSI_TYPE "text/x-perl-server-parsed-html"
/* PerlSetVar */
#define MAX_PERL_CONF_VARS 10
/* must alloc for PerlModule ... */
#define MAX_PERL_MODS 10

#ifndef NO_PERL_STACKED_HANDLERS
#define PERL_STACKED_HANDLERS
#endif
#ifndef NO_PERL_METHOD_HANDLERS
#define PERL_METHOD_HANDLERS
#endif
#ifndef NO_PERL_SECTIONS
#define PERL_SECTIONS
#endif

#ifdef APACHE_SSL
#define PERL_DONE_STARTUP 1
#else
#define PERL_DONE_STARTUP 2
#endif

/* some 1.2.x/1.3.x compat stuff */

#if MODULE_MAGIC_NUMBER > 19970909

#define mod_perl_warn(s,msg) \
    aplog_error(APLOG_MARK, APLOG_WARNING | APLOG_NOERRNO, s, msg)

#define mod_perl_error(s,msg) \
    aplog_error(APLOG_MARK, APLOG_ERR | APLOG_NOERRNO, s, msg)

#define mod_perl_notice(s,msg) \
    aplog_error(APLOG_MARK, APLOG_NOERRNO|APLOG_NOTICE, s, msg)

#define mod_perl_log_reason(msg, file, r) \
    aplog_error(APLOG_MARK, APLOG_ERR | APLOG_NOERRNO, r->server, \
                "access to %s failed for %s, reason: %s", \
                file, \
                get_remote_host(r->connection, \
				r->per_dir_config, REMOTE_NAME), \
                msg)

#else

#define mod_perl_error(s,msg) log_error(msg,s)
#define mod_perl_warn   mod_perl_error
#define mod_perl_notice mod_perl_error
#define mod_perl_log_reason log_reason
#endif                    

#if MODULE_MAGIC_NUMBER < 19970719
#define is_initial_req(r) ((r->main == NULL) && (r->prev == NULL)) 
#endif

#ifndef API_EXPORT
#define API_EXPORT(type)    type
#endif

#ifndef MODULE_VAR_EXPORT
#define MODULE_VAR_EXPORT
#endif

#ifdef MULTITHREAD
#include "multithread.h"
extern void *mod_perl_mutex;
#else
#define mod_perl_mutex NULL 
extern void *mod_perl_dummy_mutex;
#endif

#ifndef MULTITHREAD_H
typedef void mutex;
#define MULTI_OK (0)
#define create_mutex(name)	((mutex *)mod_perl_dummy_mutex)
#define acquire_mutex(mutex_id)	((int)MULTI_OK)
#define release_mutex(mutex_id)	((int)MULTI_OK)

#endif

#define PERL_SET_CUR_HOOK(h) \
{ \
   perl_dir_config *cld; \
   if(r->per_dir_config) { \
       cld = get_module_config(r->per_dir_config, &perl_module); \
       table_set(cld->vars, "PERL_CALLBACK", h); \
   } \
}

#ifdef PERL_STACKED_HANDLERS
#define PERL_TAKE ITERATE
#define PERL_CMD_INIT  Nullav
#define PERL_CMD_TYPE  AV

#define mod_perl_can_stack_handlers(sv) (SvTRUE(sv) && 1)

/* always enable child_init for perl_init_ids */
#if (MODULE_MAGIC_NUMBER >= 19970719) && !defined(WIN32)
#define perl_init_ids
# ifdef NO_PERL_CHILD_INIT
#  undef NO_PERL_CHILD_INIT
# endif
# ifdef NO_PERL_CHILD_EXIT
#  undef NO_PERL_CHILD_EXIT
# endif
#endif

#ifndef perl_init_ids
#define perl_init_ids mod_perl_init_ids()
#endif

#define PERL_CALLBACK(h,name) \
PERL_SET_CUR_HOOK(h); \
(void)acquire_mutex(mod_perl_mutex); \
status = perl_run_stacked_handlers(h, r, Nullav); \
if((status != OK) && (status != DECLINED)) { \
    MP_TRACE(fprintf(stderr, "%s handlers returned %d\n", h, status)); \
} \
else if(AvTRUE(name)) { \
    status = perl_run_stacked_handlers(h, r, name); \
} \
(void)release_mutex(mod_perl_mutex); \
MP_TRACE(fprintf(stderr, "%s handlers returned %d\n", h, status))


#else

#define PERL_TAKE TAKE1
#define PERL_CMD_INIT  NULL
#define PERL_CMD_TYPE  char

#define mod_perl_can_stack_handlers(sv) (SvTRUE(sv) && 0)

#define PERL_CALLBACK(h,name) \
PERL_SET_CUR_HOOK(h); \
if(name != NULL) { \
    SV *sv; \
    (void)acquire_mutex(mod_perl_mutex); \
    sv = newSVpv(name,0); \
    status = perl_call_handler(sv, r, Nullav); \
    SvREFCNT_dec(sv); \
    (void)release_mutex(mod_perl_mutex); \
    MP_TRACE(fprintf(stderr, "perl_call %s '%s' returned: %d\n", h,name,status)); \
} \
else { \
    MP_TRACE(fprintf(stderr, "mod_perl: declining to handle %s, no callback defined\n", h)); \
}

#endif

#if MODULE_MAGIC_NUMBER >= 19961007
#define CHAR_P const char *
#else
#define CHAR_P char * 
#endif

/* bleh */
#if MODULE_MAGIC_NUMBER >= 19961125 
#define PERL_READ_SETUP setup_client_block(r, REQUEST_CHUNKED_ERROR); 
#else
#define PERL_READ_SETUP
#endif 

#if MODULE_MAGIC_NUMBER >= 19970622 
#define PERL_SET_READ_LENGTH  r->read_length = 0
#else
#define PERL_SET_READ_LENGTH
#endif 

#if MODULE_MAGIC_NUMBER >= 19961125 
#define PERL_READ_CLIENT \
if(should_client_block(r)) { \
    nrd = get_client_block(r, buffer, bufsiz); \
    PERL_SET_READ_LENGTH; \
} 
#else 
#define PERL_READ_CLIENT \
nrd = read_client_block(r, buffer, bufsiz); 
#endif       

#define PERL_READ_FROM_CLIENT \
PERL_READ_SETUP; \
PERL_READ_CLIENT

#if MODULE_MAGIC_NUMBER >= 19961211
#define SENDN_TO_CLIENT rwrite(buffer, n, r) 

#else

/* this was private in http_protocol.c */
#define SET_BYTES_SENT(r) \
  do { if (r->sent_bodyct) \
	  bgetopt (r->connection->client, BO_BYTECT, &r->bytes_sent); \
  } while (0)

#define SENDN_TO_CLIENT \
    bwrite(r->connection->client, buffer, n); \
    SET_BYTES_SENT(r)
#endif

#define PUSHelt(key,val,klen) \
{ \
    SV *psv = (SV*)newSVpv(val, 0); \
    SvTAINTED_on(psv); \
    XPUSHs(sv_2mortal((SV*)newSVpv(key, klen))); \
    XPUSHs(sv_2mortal((SV*)psv)); \
}

#define CGIENVinit \
       int i; \
       char *tz = NULL; \
       table_entry *elts = NULL; \
       if(table_get(env_arr,"GATEWAY_INTERFACE") != PERL_GATEWAY_INTERFACE) { \
           add_common_vars(r); \
           add_cgi_vars(r); \
           elts = (table_entry *)env_arr->elts; \
           tz = getenv("TZ"); \
           table_set (env_arr, "PATH", DEFAULT_PATH); \
           table_set (env_arr, "GATEWAY_INTERFACE", PERL_GATEWAY_INTERFACE); \
       }

/* on/off switches for callback hooks during server startup/shutdown */

#ifndef NO_PERL_DISPATCH
#define PERL_DISPATCH

#define PERL_DISPATCH_HOOK perl_dispatch

#define PERL_DISPATCH_CMD_ENTRY \
"PerlDispatchHandler", perl_cmd_dispatch_handlers, \
    NULL, \
    OR_ALL, TAKE1, "the Perl Dispatch handler routine name"

#define PERL_DISPATCH_CREATE(s) s->PerlDispatchHandler = NULL
#else
#define PERL_DISPATCH_HOOK NULL
#define PERL_DISPATCH_CMD_ENTRY NULL
#define PERL_DISPATCH_CREATE(s)
#endif

#ifndef NO_PERL_CHILD_INIT
#define PERL_CHILD_INIT

#define PERL_CHILD_INIT_HOOK perl_child_init

#define PERL_CHILD_INIT_CMD_ENTRY \
"PerlChildInitHandler", perl_cmd_child_init_handlers, \
    NULL,	 \
    RSRC_CONF, PERL_TAKE, "the Perl Child init handler routine name"  

#define PERL_CHILD_INIT_CREATE(s) s->PerlChildInitHandler = PERL_CMD_INIT
#else
#define PERL_CHILD_INIT_HOOK NULL
#define PERL_CHILD_INIT_CMD_ENTRY NULL
#define PERL_CHILD_INIT_CREATE(s) 
#endif

#ifndef NO_PERL_CHILD_EXIT
#define PERL_CHILD_EXIT

#define PERL_CHILD_EXIT_HOOK perl_child_exit

#define PERL_CHILD_EXIT_CMD_ENTRY \
"PerlChildExitHandler", perl_cmd_child_exit_handlers, \
    NULL,	 \
    RSRC_CONF, PERL_TAKE, "the Perl Child exit handler routine name"  

#define PERL_CHILD_EXIT_CREATE(s) s->PerlChildExitHandler = PERL_CMD_INIT
#else
#define PERL_CHILD_EXIT_HOOK NULL
#define PERL_CHILD_EXIT_CMD_ENTRY NULL
#define PERL_CHILD_EXIT_CREATE(s) 
#endif

/* on/off switches for callback hooks during request stages */

#ifndef NO_PERL_POST_READ_REQUEST
#define PERL_POST_READ_REQUEST

#define PERL_POST_READ_REQUEST_HOOK perl_post_read_request

#define PERL_POST_READ_REQUEST_CMD_ENTRY \
"PerlPostReadRequestHandler", perl_cmd_post_read_request_handlers, \
    NULL, \
    RSRC_CONF, PERL_TAKE, "the Perl Post Read Request handler routine name" 

#define PERL_POST_READ_REQUEST_CREATE(s) s->PerlPostReadRequestHandler = PERL_CMD_INIT
#else
#define PERL_POST_READ_REQUEST_HOOK NULL
#define PERL_POST_READ_REQUEST_CMD_ENTRY NULL
#define PERL_POST_READ_REQUEST_CREATE(s)
#endif

#ifndef NO_PERL_TRANS
#define PERL_TRANS

#define PERL_TRANS_HOOK perl_translate

#define PERL_TRANS_CMD_ENTRY \
"PerlTransHandler", perl_cmd_trans_handlers, \
    NULL,	 \
    RSRC_CONF, PERL_TAKE, "the Perl Translation handler routine name"  

#define PERL_TRANS_CREATE(s) s->PerlTransHandler = PERL_CMD_INIT
#else
#define PERL_TRANS_HOOK NULL
#define PERL_TRANS_CMD_ENTRY NULL
#define PERL_TRANS_CREATE(s) 
#endif


#ifndef NO_PERL_AUTHEN
#define PERL_AUTHEN

#define PERL_AUTHEN_HOOK perl_authenticate

#define PERL_AUTHEN_CMD_ENTRY \
"PerlAuthenHandler", perl_cmd_authen_handlers, \
    NULL, \
    OR_ALL, PERL_TAKE, "the Perl Authentication handler routine name"

#define PERL_AUTHEN_CREATE(s) s->PerlAuthenHandler = PERL_CMD_INIT
#else
#define PERL_AUTHEN_HOOK NULL
#define PERL_AUTHEN_CMD_ENTRY NULL
#define PERL_AUTHEN_CREATE(s)
#endif

#ifndef NO_PERL_AUTHZ
#define PERL_AUTHZ

#define PERL_AUTHZ_HOOK perl_authorize

#define PERL_AUTHZ_CMD_ENTRY \
"PerlAuthzHandler", perl_cmd_authz_handlers, \
    NULL, \
    OR_ALL, PERL_TAKE, "the Perl Authorization handler routine name" 
#define PERL_AUTHZ_CREATE(s) s->PerlAuthzHandler = PERL_CMD_INIT
#else
#define PERL_AUTHZ_HOOK NULL
#define PERL_AUTHZ_CMD_ENTRY NULL
#define PERL_AUTHZ_CREATE(s)
#endif

#ifndef NO_PERL_ACCESS
#define PERL_ACCESS

#define PERL_ACCESS_HOOK perl_access

#define PERL_ACCESS_CMD_ENTRY \
"PerlAccessHandler", perl_cmd_access_handlers, \
    NULL, \
    OR_ALL, PERL_TAKE, "the Perl Access handler routine name" 

#define PERL_ACCESS_CREATE(s) s->PerlAccessHandler = PERL_CMD_INIT
#else
#define PERL_ACCESS_HOOK NULL
#define PERL_ACCESS_CMD_ENTRY NULL
#define PERL_ACCESS_CREATE(s)
#endif

/* un-tested hooks */

#ifndef NO_PERL_TYPE
#define PERL_TYPE

#define PERL_TYPE_HOOK perl_type_checker

#define PERL_TYPE_CMD_ENTRY \
"PerlTypeHandler", perl_cmd_type_handlers, \
    NULL, \
    OR_ALL, PERL_TAKE, "the Perl Type check handler routine name" 

#define PERL_TYPE_CREATE(s) s->PerlTypeHandler = PERL_CMD_INIT
#else
#define PERL_TYPE_HOOK NULL
#define PERL_TYPE_CMD_ENTRY NULL
#define PERL_TYPE_CREATE(s) 
#endif

#ifndef NO_PERL_FIXUP
#define PERL_FIXUP

#define PERL_FIXUP_HOOK perl_fixup

#define PERL_FIXUP_CMD_ENTRY \
"PerlFixupHandler", perl_cmd_fixup_handlers, \
    NULL, \
    OR_ALL, PERL_TAKE, "the Perl Fixup handler routine name" 

#define PERL_FIXUP_CREATE(s) s->PerlFixupHandler = PERL_CMD_INIT
#else
#define PERL_FIXUP_HOOK NULL
#define PERL_FIXUP_CMD_ENTRY NULL
#define PERL_FIXUP_CREATE(s)
#endif

#ifndef NO_PERL_LOG
#define PERL_LOG

#define PERL_LOG_HOOK perl_logger

#define PERL_LOG_CMD_ENTRY \
"PerlLogHandler", perl_cmd_log_handlers, \
    NULL, \
    OR_ALL, PERL_TAKE, "the Perl Log handler routine name" 

#define PERL_LOG_CREATE(s) s->PerlLogHandler = PERL_CMD_INIT
#else
#define PERL_LOG_HOOK NULL
#define PERL_LOG_CMD_ENTRY NULL
#define PERL_LOG_CREATE(s) 
#endif

#ifndef NO_PERL_CLEANUP
#define PERL_CLEANUP

#define PERL_CLEANUP_HOOK perl_cleanup

#define PERL_CLEANUP_CMD_ENTRY \
"PerlCleanupHandler", perl_cmd_cleanup_handlers, \
    NULL, \
    OR_ALL, PERL_TAKE, "the Perl Cleanup handler routine name" 

#define PERL_CLEANUP_CREATE(s) s->PerlCleanupHandler = PERL_CMD_INIT
#else
#define PERL_CLEANUP_HOOK NULL
#define PERL_CLEANUP_CMD_ENTRY NULL
#define PERL_CLEANUP_CREATE(s)
#endif

#ifndef NO_PERL_INIT
#define PERL_INIT

#define PERL_INIT_HOOK perl_init

#define PERL_INIT_CMD_ENTRY \
"PerlInitHandler", perl_cmd_init_handlers, \
    NULL, \
    OR_ALL, PERL_TAKE, "the Perl Init handler routine name" 

#define PERL_INIT_CREATE(s) s->PerlInitHandler = PERL_CMD_INIT
#else
#define PERL_INIT_HOOK NULL
#define PERL_INIT_CMD_ENTRY NULL
#define PERL_INIT_CREATE(s) 
#endif

#ifndef NO_PERL_HEADER_PARSER
#define PERL_HEADER_PARSER

#define PERL_HEADER_PARSER_HOOK perl_header_parser

#define PERL_HEADER_PARSER_CMD_ENTRY \
"PerlHeaderParserHandler", perl_cmd_header_parser_handlers, \
    NULL, \
    OR_ALL, PERL_TAKE, "the Perl Header Parser handler routine name" 

#define PERL_HEADER_PARSER_CREATE(s) s->PerlHeaderParserHandler = PERL_CMD_INIT
#else
#define PERL_HEADER_PARSER_HOOK NULL
#define PERL_HEADER_PARSER_CMD_ENTRY NULL
#define PERL_HEADER_PARSER_CREATE(s)
#endif

typedef struct {
    char *PerlPassEnv;
    char **PerlScript;
    char **PerlModules;
    int  NumPerlModules;
    int  NumPerlScript;
    int  PerlTaintCheck;
    int  PerlWarn;
    int FreshRestart;
    PERL_CMD_TYPE *PerlPostReadRequestHandler;
    PERL_CMD_TYPE *PerlTransHandler;
    PERL_CMD_TYPE *PerlChildInitHandler;
    PERL_CMD_TYPE *PerlChildExitHandler;
} perl_server_config;

typedef struct {
    char *PerlDispatchHandler;
    PERL_CMD_TYPE *PerlHandler;
    PERL_CMD_TYPE *PerlAuthenHandler;
    PERL_CMD_TYPE *PerlAuthzHandler;
    PERL_CMD_TYPE *PerlAccessHandler;
    PERL_CMD_TYPE *PerlTypeHandler;
    PERL_CMD_TYPE *PerlFixupHandler;
    PERL_CMD_TYPE *PerlLogHandler;
    PERL_CMD_TYPE *PerlCleanupHandler;
    PERL_CMD_TYPE *PerlHeaderParserHandler;
    PERL_CMD_TYPE *PerlInitHandler;
    table *env;
    table *vars;
    U32 flags;
} perl_dir_config;

typedef struct {
    int is_method;
    int is_anon;
    int in_perl;
    SV *class;
    char *method;
} mod_perl_handler;

extern module MODULE_VAR_EXPORT perl_module;

/* a couple for -Wall sanity sake */
int basic_http_header(request_rec *r);
int translate_name (request_rec *);
int log_transaction (request_rec *r);

/* mod_perl prototypes */

/* perlxsi.c */
void xs_init (void);

/* mod_perl.c */

/* generic handler stuff */ 
int perl_handler_ismethod(HV *class, char *sub);
API_EXPORT(int) perl_call_handler(SV *sv, request_rec *r, AV *args);

/* stacked handler stuff */
int mod_perl_push_handlers(SV *self, char *hook, SV *sub, AV *handlers);
SV *mod_perl_pop_handlers(SV *self, SV *hook);
void *mod_perl_clear_handlers(SV *self, SV *hook);
SV *mod_perl_fetch_handlers(SV *self, SV *hook);
int perl_run_stacked_handlers(char *hook, request_rec *r, AV *handlers);

/* plugin slots */
void perl_startup(server_rec *s, pool *p);
int perl_handler(request_rec *r);
void perl_child_init(server_rec *, pool *);
void perl_child_exit(server_rec *, pool *);
int perl_translate(request_rec *r);
int perl_authenticate(request_rec *r);
int perl_authorize(request_rec *r);
int perl_access(request_rec *r);
int perl_type_checker(request_rec *r);
int perl_fixup(request_rec *r);
int perl_post_read_request(request_rec *r);
int perl_logger(request_rec *r);
int perl_header_parser(request_rec *r);
int perl_hook(char *name);
int PERL_RUNNING(void);

/* per-request gunk */
int mod_perl_sent_header(request_rec *r, int val);
int mod_perl_seqno(SV *self, int inc);
request_rec *perl_request_rec(request_rec *);
void perl_setup_env(request_rec *r);
SV  *perl_bless_request_rec(request_rec *); 
void perl_set_request_rec(request_rec *); 
void mod_perl_cleanup_handler(void *data);
void mod_perl_end_cleanup(void *data);
void mod_perl_register_cleanup(request_rec *r, SV *sv);
void mod_perl_noop(void *data);
SV *mod_perl_resolve_handler(request_rec *r, SV *sv, mod_perl_handler *h); 
mod_perl_handler *mod_perl_new_handler(request_rec *r, SV *sv);
void mod_perl_destroy_handler(void *data);

/* perl_util.c */

void perl_tie_hash(HV *hv, char *class);
void perl_util_cleanup(void);
void mod_perl_clear_rgy_endav(request_rec *r, SV *sv);
void perl_run_rgy_endav(char *s);
void perl_run_endav(char *s);
void perl_call_halt(void);
CV *empty_anon_sub(void);
void perl_reload_inc(void);
int perl_require_module(char *, server_rec *);
int perl_load_startup_script(server_rec *s, pool *p, char *script, I32 my_warn);
void newCONSTSUB(HV *stash, char *name, SV *sv);
void perl_clear_env(void);
void mod_perl_init_ids(void);
int perl_eval_ok(server_rec *);
void perl_incpush(char *s);

/* perlio.c */

void perl_soak_script_output(request_rec *r);
void perl_stdin2client(request_rec *);
API_EXPORT(void) perl_stdout2client(request_rec *); 

/* perl_config.c */

char *mod_perl_auth_name(request_rec *r, char *val);

void *perl_merge_dir_config(pool *p, void *basev, void *addv);
void *perl_create_dir_config(pool *p, char *dirname);
void *perl_create_server_config(pool *p, server_rec *s);

CHAR_P perl_section (cmd_parms *cmd, void *dummy, CHAR_P arg);
CHAR_P perl_end_section (cmd_parms *cmd, void *dummy);
CHAR_P perl_limit_section(cmd_parms *cmd, void *dummy, HV *hv);
CHAR_P perl_urlsection (cmd_parms *cmd, void *dummy, HV *hv);
CHAR_P perl_dirsection (cmd_parms *cmd, void *dummy, HV *hv);
CHAR_P perl_filesection (cmd_parms *cmd, void *dummy, HV *hv);
void perl_add_file_conf (server_rec *s, void *url_config);
void perl_handle_command(cmd_parms *cmd, void *dummy, char *line);
void perl_handle_command_hv(HV *hv, char *key, cmd_parms *cmd, void *dummy);
void perl_handle_command_av(AV *av, I32 n, char *key, cmd_parms *cmd, void *dummy);

CHAR_P perl_cmd_script (cmd_parms *parms, void *dummy, char *arg);
CHAR_P perl_cmd_module (cmd_parms *parms, void *dummy, char *arg);
CHAR_P perl_cmd_var(cmd_parms *cmd, perl_dir_config *rec, char *key, char *val);
CHAR_P perl_cmd_setenv(cmd_parms *cmd, perl_dir_config *rec, char *key, char *val);
CHAR_P perl_cmd_env (cmd_parms *cmd, perl_dir_config *rec, int arg);
CHAR_P perl_cmd_pass_env (cmd_parms *parms, void *dummy, char *arg);
CHAR_P perl_cmd_sendheader (cmd_parms *cmd, perl_dir_config *rec, int arg);
CHAR_P perl_cmd_tainting (cmd_parms *parms, void *dummy, int arg);
CHAR_P perl_cmd_warn (cmd_parms *parms, void *dummy, int arg);
CHAR_P perl_cmd_fresh_restart (cmd_parms *parms, void *dummy, int arg);

CHAR_P perl_cmd_dispatch_handlers (cmd_parms *parms, perl_dir_config *rec, char *arg);
CHAR_P perl_cmd_init_handlers (cmd_parms *parms, perl_dir_config *rec, char *arg);
CHAR_P perl_cmd_cleanup_handlers (cmd_parms *parms, perl_dir_config *rec, char *arg);
CHAR_P perl_cmd_header_parser_handlers (cmd_parms *parms, perl_dir_config *rec, char *arg);
CHAR_P perl_cmd_post_read_request_handlers (cmd_parms *parms, void *dumm, char *arg);
CHAR_P perl_cmd_trans_handlers (cmd_parms *parms, void *dumm, char *arg);
CHAR_P perl_cmd_child_init_handlers (cmd_parms *parms, void *dumm, char *arg);
CHAR_P perl_cmd_child_exit_handlers (cmd_parms *parms, void *dumm, char *arg);
CHAR_P perl_cmd_authen_handlers (cmd_parms *parms, perl_dir_config *rec, char *arg);
CHAR_P perl_cmd_authz_handlers (cmd_parms *parms, perl_dir_config *rec, char *arg);
CHAR_P perl_cmd_access_handlers (cmd_parms *parms, perl_dir_config *rec, char *arg);
CHAR_P perl_cmd_type_handlers (cmd_parms *parms, perl_dir_config *rec, char *arg);
CHAR_P perl_cmd_fixup_handlers (cmd_parms *parms, perl_dir_config *rec, char *arg);
CHAR_P perl_cmd_handler_handlers (cmd_parms *parms, perl_dir_config *rec, char *arg);
CHAR_P perl_cmd_log_handlers (cmd_parms *parms, perl_dir_config *rec, char *arg);

void mod_perl_dir_env(perl_dir_config *cld);
void mod_perl_pass_env(pool *p, perl_server_config *cls);
