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

extern listen_rec *listeners;
extern int mod_perl_socketexitoption;
extern int mod_perl_weareaforkedchild;   

#if defined(PERL_STACKED_HANDLERS) && defined(PERL_GET_SET_HANDLERS)

#define PER_DIR_CONFIG 1
#define PER_SRV_CONFIG 2

typedef struct {
    int type;
    char *name;
    void *offset;
    void (*set_func) (void *, void *, SV *);
} perl_handler_table;

typedef struct {
    I32 fill;
    AV *av;
    AV **ptr;
} perl_save_av;

static void set_handler_dir (perl_handler_table *tab, request_rec *r, SV *sv);
static void set_handler_srv (perl_handler_table *tab, request_rec *r, SV *sv);

#define HandlerDirEntry(name,member) \
PER_DIR_CONFIG, name, (void*)XtOffsetOf(perl_dir_config,member), \
(void(*)(void *, void *, SV *)) set_handler_dir

#define HandlerSrvEntry(name,member) \
PER_SRV_CONFIG, name, (void*)XtOffsetOf(perl_server_config,member), \
(void(*)(void *, void *, SV *)) set_handler_srv

static perl_handler_table handler_table[] = {
    {HandlerSrvEntry("PerlPostReadRequestHandler", PerlPostReadRequestHandler)},
    {HandlerSrvEntry("PerlTransHandler", PerlTransHandler)},
    {HandlerDirEntry("PerlHeaderParserHandler", PerlHeaderParserHandler)},
    {HandlerDirEntry("PerlAccessHandler", PerlAccessHandler)},
    {HandlerDirEntry("PerlAuthenHandler", PerlAuthenHandler)},
    {HandlerDirEntry("PerlAuthzHandler", PerlAuthzHandler)},
    {HandlerDirEntry("PerlTypeHandler", PerlTypeHandler)},
    {HandlerDirEntry("PerlFixupHandler", PerlFixupHandler)},
    {HandlerDirEntry("PerlHandler", PerlHandler)},
    {HandlerDirEntry("PerlLogHandler", PerlLogHandler)},
    { FALSE, NULL }
};

static void perl_restore_av(void *data)
{
    perl_save_av *save_av = (perl_save_av *)data;

    if(save_av->fill != DONE) {
	AvFILLp(*save_av->ptr) = save_av->fill;
    }
    else if(save_av->av != Nullav) {
	*save_av->ptr = save_av->av;
    }
}

static void perl_handler_merge_avs(char *hook, AV **dest)
{
    int i = 0;
    HV *hv = perl_get_hv("Apache::PerlStackedHandlers", FALSE);
    SV **svp = hv_fetch(hv, hook, strlen(hook), FALSE);
    AV *base;
    
    if(!(svp && SvROK(*svp)))
	return;

    base = (AV*)SvRV(*svp);
    for(i=0; i<=AvFILL(base); i++) { 
	SV *sv = *av_fetch(base, i, FALSE);
	av_push(*dest, sv);
    }
}

static void set_handler_base(void *ptr, perl_handler_table *tab, pool *p, SV *sv) 
{
    AV **av = (AV **)((char *)ptr + (int)(long)tab->offset);

    perl_save_av *save_av = 
	(perl_save_av *)palloc(p, sizeof(perl_save_av));

    save_av->fill = DONE;
    save_av->av = Nullav;
    
    if((sv == &sv_undef) || (SvIOK(sv) && SvIV(sv) == DONE)) {
	if(AvTRUE(*av)) {
	    save_av->fill = AvFILL(*av);
	    AvFILLp(*av) = -1;
	}
    }
    else if(SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVAV) {
	if(AvTRUE(*av))
	    save_av->av = av_copy_array(*av);
	*av = (AV*)SvRV(sv);
	++SvREFCNT(*av);
    }
    else {
	croak("Can't set_handler with that value");
    }
    save_av->ptr = av;
    register_cleanup(p, save_av, perl_restore_av, mod_perl_noop);
}

static void set_handler_dir(perl_handler_table *tab, request_rec *r, SV *sv)
{
    dPPDIR; 
    set_handler_base((void*)cld, tab, r->pool, sv);
}

static void set_handler_srv(perl_handler_table *tab, request_rec *r, SV *sv)
{
    dPSRV(r->server); 
    set_handler_base((void*)cls, tab, r->pool, sv);
}

static perl_handler_table *perl_handler_lookup(char *name)
{
    int i;
    for (i=0; handler_table[i].name; i++) {
	perl_handler_table *tab = &handler_table[i];
        if(strEQ(name, tab->name))
	    return tab;
    }
    return NULL;
}


static SV *get_handlers(request_rec *r, char *hook)
{
    AV *avcopy;
    AV **av;
    dPPDIR;
    dPSRV(r->server);
    void *ptr;
    perl_handler_table *tab = perl_handler_lookup(hook);

    if(!tab) return Nullsv;

    if(tab->type == PER_DIR_CONFIG)
	ptr = (void*)cld;
    else
	ptr = (void*)cls;

    av = (AV **)((char *)ptr + (int)(long)tab->offset);

    if(*av) 
	avcopy = av_copy_array(*av);
    else
	avcopy = newAV();

    perl_handler_merge_avs(hook, &avcopy);

    return newRV_noinc((SV*)avcopy);
}

static void set_handlers(request_rec *r, SV *hook, SV *sv)
{
    perl_handler_table *tab = perl_handler_lookup(SvPV(hook,na));
    if(tab && tab->set_func) 
        (*tab->set_func)(tab, r, sv);

    (void)hv_delete_ent(perl_get_hv("Apache::PerlStackedHandlers", FALSE),
			hook, G_DISCARD, FALSE);
}
#endif

static char *r_keys[] = { "_r", "r", NULL };

request_rec *sv2request_rec(SV *in, char *class, CV *cv)
{
    request_rec *r = NULL;
    SV *sv = Nullsv;

    if(in == &sv_undef) return NULL;

    if(SvROK(in) && (SvTYPE(SvRV(in)) == SVt_PVHV)) {
	int i;
	for (i=0; r_keys[i]; i++) {
	    int klen = strlen(r_keys[i]);
	    if(hv_exists((HV*)SvRV(in), r_keys[i], klen) &&
	       (sv = *hv_fetch((HV*)SvRV(in), 
			       r_keys[i], klen, FALSE)))
		break;
	}
	if(!sv)
	    croak("method `%s' invoked by a `%s' object with no `r' key!",
		  GvNAME(CvGV(cv)), HvNAME(SvSTASH(SvRV(in))));
    }

    if(!sv) sv = in;
    if(SvROK(sv) && (SvTYPE(SvRV(sv)) == SVt_PVMG)) {
	if(sv_derived_from(sv, class))
	    r = (request_rec *) SvIV((SV*)SvRV(sv));
	else
	    return NULL;
    }
    else if((r = perl_request_rec(NULL))) {
	/*ok*/
    } 
    else {
	croak("Apache->%s called without setting Apache->request!",
	      GvNAME(CvGV(cv)));
    }
    return r;
}

#if MODULE_MAGIC_NUMBER < 19970909
static void
child_terminate(request_rec *r)
{
#ifndef WIN32
    log_transaction(r);
#endif
    exit(0);
}
#endif

#if MODULE_MAGIC_NUMBER < 19980317
int basic_http_header(request_rec *r);
#endif

#if MODULE_MAGIC_NUMBER < 19980201
unsigned get_server_port(const request_rec *r)
{
    unsigned port = r->server->port ? r->server->port : 80;

    return r->hostname ? ntohs(r->connection->local_addr.sin_port)
	: port;
}
#endif

pool *perl_get_startup_pool(void)
{
    SV *sv = perl_get_sv("Apache::__POOL", FALSE);
    if(sv) {
	IV tmp = SvIV((SV*)SvRV(sv));
	return (pool *)tmp;
    }
    return NULL;
}

server_rec *perl_get_startup_server(void)
{
    SV *sv = perl_get_sv("Apache::__SERVER", FALSE);
    if(sv) {
	IV tmp = SvIV((SV*)SvRV(sv));
	return (server_rec *)tmp;
    }
    return NULL;
}

#define TABLE_GET_SET(table, do_taint) \
if(key == NULL) { \
    ST(0) = mod_perl_tie_table(table); \
    XSRETURN(1); \
} \
else { \
    char *val; \
    if(table && (val = (char *)table_get(table, key))) \
	RETVAL = newSVpv(val, 0); \
    else \
        RETVAL = newSV(0); \
    if(do_taint) SvTAINTED_on(RETVAL); \
    if(table && (items > 2)) { \
	if(ST(2) == &sv_undef) \
	    table_unset(table, key); \
	else \
	    table_set(table, key, SvPV(ST(2),na)); \
    } \
}

#define MP_CHECK_REQ(r,f) \
    if(!r) croak("`%s' called without setting Apache->request!", f)

MODULE = Apache  PACKAGE = Apache   PREFIX = mod_perl_

PROTOTYPES: DISABLE

BOOT:
    items = items; /*avoid warning*/ 

int
max_requests_per_child(...)

    CODE:
    items = items; /*avoid warning*/
    RETVAL = 0;
#ifdef WIN32
    croak("Apache->max_requests_per_child not supported under win32!");
#else
    RETVAL = max_requests_per_child;
    warn("use Apache::Globals->max_request_per_child, not Apache->");
#endif
    OUTPUT:
    RETVAL

SV *
current_callback(r)
    Apache     r

    CODE:
    RETVAL = perl_get_sv("Apache::__CurrentCallback", TRUE);

    OUTPUT:
    RETVAL

int
mod_perl_sent_header(r, val=0)
    Apache     r
    int val
    
int
mod_perl_seqno(self, inc=0)
    SV *self
    int inc

int
perl_hook(name)
    char *name

#if defined(PERL_GET_SET_HANDLERS)
SV *
get_handlers(r, hook)
    Apache     r
    char *hook

    CODE:
#ifdef get_handlers
    get_handlers(r,hook);
#else
    RETVAL = get_handlers(r,hook);
#endif
   
    OUTPUT:
    RETVAL

void    
set_handlers(r, hook, sv)
    Apache     r
    SV *hook
    SV *sv

#endif

int
mod_perl_push_handlers(self, hook, cv)
    SV *self
    char *hook
    SV *cv;

    CODE:
    RETVAL = mod_perl_push_handlers(self, hook, cv, Nullav);

    OUTPUT:
    RETVAL

int
mod_perl_can_stack_handlers(self)
    SV *self

void
mod_perl_register_cleanup(r, sv)
    Apache     r
    SV *sv

    ALIAS:
    Apache::post_connection = 1

    PREINIT:
    ix = ix; /* avoid -Wall warning */
    
#define APACHE_REGISTRY_CURSTASH perl_get_sv("Apache::Registry::curstash", TRUE)

void
mod_perl_clear_rgy_endav(r, sv=APACHE_REGISTRY_CURSTASH)
    Apache     r
    SV *sv

void
mod_perl_stash_rgy_endav(r, sv=APACHE_REGISTRY_CURSTASH)
    Apache     r
    SV *sv

    CODE:
    perl_stash_rgy_endav(r->uri, sv);

I32
module(sv, name)
    SV *sv
    char *name

    CODE:
    RETVAL = (sv && perl_module_is_loaded(name));

    OUTPUT:
    RETVAL

void
untaint(...)

    PREINIT:
    int i;

    CODE:
    if(!tainting) XSRETURN_EMPTY;
    for(i=1; i<items; i++) 
        mod_perl_untaint(ST(i));

void
taint(...)

    PREINIT:
    int i;

    CODE:
    if(!tainting) XSRETURN_EMPTY;
    for(i=1; i<items; i++)
        sv_magic(ST(i), Nullsv, 't', Nullch, 0);

#ifndef WIN32

void
child_terminate(r)
    Apache     r

#endif

#CORE::exit only causes trouble when we're embedded
void
exit(...)

    PREINIT:
    int sts = 0;
    request_rec *r = NULL;

    CODE:
    /* $r->exit */
    r = sv2request_rec(ST(0), "Apache", cv);

    if(items > 1) {
        sts = (int)SvIV(ST(1));
    }
    else { /* Apache::exit() */
	if(SvTRUE(ST(0)) && SvIOK(ST(0)))
	    sts = (int)SvIV(ST(0));
    }

    MP_CHECK_REQ(r, "Apache::exit");

    if(!r->connection->aborted)
        rflush(r);
#ifndef WIN32
    if((sts == DONE)||
       ((mod_perl_weareaforkedchild) && (mod_perl_socketexitoption > 1)))  
        child_terminate(r); /* only 1.3b1+ does this right */
#endif
    perl_call_halt(sts);

# toggle closing of the http socket on fork...
void 
forkoption(i)
    int i;

    CODE: 
    if ((i<0)||(i>3)) { 
	croak("Usage: Apache::forkoption(0|1|2|3)"); 
    }
    else {
	mod_perl_socketexitoption = i;
    } 
    /* probably SHOULD set weareaforkedchild = 0 if socketexitoption
     * is set to something that DOESN'T cause a forked child to
     * actually die on exit, but... 
     */

# We want the http socket closed
int 
fork(...)

    PREINIT:
    listen_rec *l;
    static listen_rec *mhl;
    dSP; dTARGET;
    int childpid;
    GV *tmpgv;

    CODE:
    RETVAL = 0; 
#ifdef HAS_FORK
    items = items; 
    EXTEND(SP,1);
    childpid = fork();

    if((childpid < 0)) {
        RETVAL=-1;
    }
    else {
	if(!childpid) {
 	    if(mod_perl_socketexitoption>1) mod_perl_weareaforkedchild++;
	    if ((mod_perl_socketexitoption==1) ||
                (mod_perl_socketexitoption==3)) {
	        /* So?  I can't get at head_listener...
	         * (It is a ring anyhow...)
                 */
		mhl = listeners;
		l = mhl;

		do {
		    if (l->fd > 0) close(l->fd);
		    l = l->next;
		} while (l != mhl);
	    }
	    if((tmpgv = gv_fetchpv("$", TRUE, SVt_PV)))
	        sv_setiv(GvSV(tmpgv), (IV)getpid());
	    hv_clear(pidstatus);
	}
	PUSHi(childpid);

	RETVAL = childpid;
    }
#else
    croak("Unsupported function fork");
#endif

    OUTPUT:
    RETVAL

#shutup AutoLoader
void 
DESTROY(r=Nullsv)
    SV     *r

    CODE:
    /*NOOP*/

#httpd.h
     
void
chdir_file(r, file=r->filename)
    Apache r
    const char *file

    CODE:
    chdir_file(file);

SV *
mod_perl_gensym(pack="Apache::Symbol")
    char *pack

char *
unescape_url(string)
char *string

    CODE:
    unescape_url(string);
    RETVAL = string;

    OUTPUT:
    RETVAL

#
# Doing our own unscape_url for the query info part of an url
#

char *
unescape_url_info(url)
    char *     url

    CODE:
    register char * trans = url ;
    char digit ;

    RETVAL = url;

    while (*url != '\0') {
        if (*url == '+')
            *trans = ' ';
	else if (*url != '%')
	    *trans = *url;
        else if (!isxdigit(url[1]) || !isxdigit(url[2]))
            *trans = '%';
        else {
            url++ ;
            digit = ((*url >= 'A') ? ((*url & 0xdf) - 'A')+10 : (*url - '0'));
            url++ ;
            *trans = (digit << 4) +
		(*url >= 'A' ? ((*url & 0xdf) - 'A')+10 : (*url - '0'));
        }
        url++, trans++ ;
    }
    *trans = '\0';

    OUTPUT:
    RETVAL

#functions from http_main.c

void
hard_timeout(r, string)
    Apache     r
    char       *string

    CODE:
#ifndef USE_THREADS
    hard_timeout(string, r);
#endif

void
soft_timeout(r, string)
    Apache     r
    char       *string

    CODE:
    soft_timeout(string, r);

void
kill_timeout(r)
    Apache     r

    CODE:
#ifndef USE_THREADS
    kill_timeout(r);
#endif

void
reset_timeout(r)
    Apache     r

#functions from http_config.c

int
translate_name(r)
    Apache     r

    CODE:
#ifdef WIN32
    croak("Apache->translate_name not supported under Win32");
    RETVAL = DECLINED;
#else
    RETVAL = translate_name(r);
#endif

    OUTPUT:
    RETVAL

#functions from http_core.c

void
custom_response(r, status, string)
    Apache     r
    int status
    char *string
    
    PREINIT:
    core_dir_config *conf;
    int type, idx500;

    CODE:
#if defined(WIN32) && (MODULE_MAGIC_NUMBER < 19980324)
    croak("Need 1.3b6+ for Apache->custom_response under win32!");
#else
    idx500 = index_of_response(HTTP_INTERNAL_SERVER_ERROR);
    conf = get_module_config(r->per_dir_config, &core_module);

    if(conf->response_code_strings == NULL) {
        conf->response_code_strings = 
	    pcalloc(r->pool,
		    sizeof(*conf->response_code_strings) * 
		    RESPONSE_CODES);
    }

    type = index_of_response(status);

    conf->response_code_strings[type] = 
       ((is_url(string) || (*string == '/')) && (*string != '"')) ? 
       pstrdup(r->pool, string) : pstrcat(r->pool, "\"", string, NULL);
#endif

int
satisfies(r)
    Apache     r

int
some_auth_required(r)
    Apache     r

void
requires(r)
    Apache     r

    PREINIT:
    AV *av;
    HV *hv;
    register int x;
    int m;
    char *t;
    MP_CONST_ARRAY_HEADER *reqs_arr;
    require_line *reqs;

    CODE:
    m = r->method_number;
    reqs_arr = requires (r);

    if (!reqs_arr)
	ST(0) = &sv_undef;
    else {
	reqs = (require_line *)reqs_arr->elts;
	iniAV(av);
        for(x=0; x < reqs_arr->nelts; x++) {
	    /* XXX should we do this or let PerlAuthzHandler? */
	    if (! (reqs[x].method_mask & (1 << m))) continue;
	    t = reqs[x].requirement;
	    iniHV(hv);
	    hv_store(hv, "method_mask", 11, 
		     newSViv((IV)reqs[x].method_mask), 0);
	    hv_store(hv, "requirement", 11, 
		     newSVpv(reqs[x].requirement,0), 0);
	    av_push(av, newRV((SV*)hv));
	}
	ST(0) = newRV_noinc((SV*)av); 
    }

int 
allow_options(r)
    Apache	r

unsigned
get_server_port(r)
    Apache	r

char *
get_remote_host(r, type=REMOTE_NAME)
    Apache	r
    int type

    CODE:
    RETVAL = (char *)get_remote_host(r->connection, 
				     r->per_dir_config, type);

    OUTPUT:
    RETVAL

const char *
get_remote_logname(r)
    Apache	r

char *
mod_perl_auth_name(r, val=NULL)
    Apache    r
    char *val

const char *
auth_type(r)
    Apache    r

const char *
document_root(r)
    Apache    r

char *
server_root_relative(rsv, name="")
    SV   *rsv
    char *name

    PREINIT:
    pool *p;
    request_rec *r;

    CODE:
    if (SvROK(rsv) && (r = sv2request_rec(rsv, "Apache", cv))) {
	p = r->pool;
    }
    else {
	if(!(p = perl_get_startup_pool()))
	   croak("Apache::server_root_relative: no startup pool available");
    }

    RETVAL = (char *)server_root_relative(p, name);

    OUTPUT:
    RETVAL

#functions from http_protocol.c

void
note_basic_auth_failure(r)
    Apache r

void
get_basic_auth_pw(r)
    Apache r

    PREINIT:
    MP_CONST_CHAR *sent_pw = NULL;
    int ret;

    PPCODE:
    ret = get_basic_auth_pw(r, &sent_pw);
    XPUSHs(sv_2mortal((SV*)newSViv(ret)));
    if(ret == OK)
	XPUSHs(sv_2mortal((SV*)newSVpv((char *)sent_pw, 0)));
    else
	XPUSHs(&sv_undef);

void
basic_http_header(r)
    Apache	r
    
    CODE:
#ifdef WIN32
    croak("Apache->basic_http_header() not supported under Win32!");
#else
    basic_http_header(r);
#endif

void
send_http_header(r, type=NULL)
    Apache	r
    char *type

    CODE:
    if(type)
        r->content_type = pstrdup(r->pool, type);
    send_http_header(r);
    mod_perl_sent_header(r, 1);
    r->status = 200; /* XXX, why??? */
 
int
send_fd(r, f)
    Apache	r
    FILE *f

    CODE:
    RETVAL = send_fd(f, r);

    OUTPUT:
    RETVAL

int
rflush(r)
    Apache     r

    CODE:
#if MODULE_MAGIC_NUMBER >= 19970103
    RETVAL = rflush(r);
#else
    RETVAL = bflush(r->connection->client);
#endif

void
read_client_block(r, buffer, bufsiz)
    Apache	r
    char    *buffer
    int      bufsiz

    PREINIT:
    long nrd = 0;

    PPCODE:
    buffer = (char*)safemalloc(bufsiz);
    PERL_READ_FROM_CLIENT;
    if ( nrd > 0 ) {
	XPUSHs(sv_2mortal(newSViv((long)nrd)));
	sv_setpvn((SV*)ST(1), buffer, nrd);
#ifdef PERL_STASH_POST_DATA
        table_set(r->subprocess_env, "POST_DATA", buffer);
#endif
        safefree(buffer);
	SvTAINTED_on((SV*)ST(1));
    } 
    else {
	ST(1) = &sv_undef;
    }

int
setup_client_block(r, policy=REQUEST_CHUNKED_ERROR)
    Apache	r
    int policy

int
should_client_block(r)
    Apache	r

void
get_client_block(r, buffer, bufsiz)
    Apache	r
    char    *buffer
    int      bufsiz

    PREINIT:
    long nrd = 0;

    PPCODE:
    buffer = (char*)palloc(r->pool, bufsiz);
    nrd = get_client_block(r, buffer, bufsiz);
    if ( nrd > 0 ) {
	XPUSHs(sv_2mortal(newSViv((long)nrd)));
	sv_setpvn((SV*)ST(1), buffer, nrd);
	SvTAINTED_on((SV*)ST(1));
    } 
    else {
	ST(1) = &sv_undef;
    }

void 
print(r, ...)
    Apache	r

    ALIAS:
    Apache::PRINT = 1

    PREINIT:
    ix = ix; /* avoid -Wall warning */

    CODE:
    if(!mod_perl_sent_header(r, 0)) {
	SV *sv = sv_newmortal();
	SV *rp = ST(0);
	SV *sendh = perl_get_sv("Apache::__SendHeader", TRUE);

	if(items > 2)
	    do_join(sv, &sv_no, MARK+1, SP); /* $sv = join '', @_[1..$#_] */
        else
	    sv_setsv(sv, ST(1));

	PUSHMARK(sp);
	XPUSHs(rp);
	XPUSHs(sv);
	PUTBACK;
	sv_setiv(sendh, 1);
	perl_call_pv("Apache::send_cgi_header", G_SCALAR);
	sv_setiv(sendh, 0);
    }
    else {
	CV *cv = GvCV(gv_fetchpv("Apache::write_client", FALSE, SVt_PVCV));
	hard_timeout("mod_perl: Apache->print", r);
	PUSHMARK(mark);
	(void)(*CvXSUB(cv))(cv); /* &Apache::write_client; */

	if(IoFLAGS(GvIOp(defoutgv)) & IOf_FLUSH) /* if $| != 0; */
#if MODULE_MAGIC_NUMBER >= 19970103
	    rflush(r);
#else
	    bflush(r->connection->client);
#endif
	kill_timeout(r);
    }

int
write_client(r, ...)
    Apache	r

    PREINIT:
    int i;
    char * buffer;
    STRLEN len;

    CODE:
    RETVAL = 0;

    for(i = 1; i <= items - 1; i++) {
	int sent = 0;
        SV *sv = SvROK(ST(i)) && (SvTYPE(SvRV(ST(i))) == SVt_PV) ?
                 (SV*)SvRV(ST(i)) : ST(i);
	buffer = SvPV(sv, len);
#ifdef APACHE_SSL
        while(len > 0) {
            sent = 0;
	    if(len < HUGE_STRING_LEN) {
	        sent = rwrite(buffer, len, r);
	    }
	    else {
	        sent = rwrite(buffer, HUGE_STRING_LEN, r);
	        buffer += HUGE_STRING_LEN;
	    }
	    if(sent < 0) {
	        mod_perl_debug(r->server, "mod_perl: rwrite returned -1");
                if(r->connection->aborted) break;
                else continue;   
	    }
	    len -= sent;
	    RETVAL += sent;
        }
#else
        if((sent = rwrite(buffer, len, r)) < 0) {
	    mod_perl_debug(r->server, "mod_perl: rwrite returned -1");
	    if(r->connection->aborted) break;
	    else continue;
        }
        RETVAL += sent;
#endif
    }

#functions from http_request.c
void
internal_redirect_handler(r, location)
    Apache	r
    char *      location

    CODE:
    internal_redirect_handler(location, r);

#functions from http_log.c

void
mod_perl_log_reason(r, reason, filename=NULL)
    Apache	r
    char *	reason
    char *	filename

    CODE:
    if(filename == NULL)
        filename = r->uri; 
    mod_perl_log_reason(reason, filename, r);

void
log_error(...)

    ALIAS:
    Apache::warn = 1
    Apache::Server::log_error = 2
    Apache::Server::warn = 3

    PREINIT:
    server_rec *s = NULL;
    request_rec *r = NULL;
    int i=0;
    char *errstr = NULL;
    SV *sv = Nullsv;

    CODE:
    if((items > 1) && (r = sv2request_rec(ST(0), "Apache", cv))) {
	s = r->server;
	i=1;
    }
    else if((items > 1) && sv_derived_from(ST(0), "Apache::Server")) {
	IV tmp = SvIV((SV*)SvRV(ST(0)));
	s = (Apache__Server )tmp;
	i=1;	

	/* if below is true, delay log_error */
	if(PERL_RUNNING() < PERL_DONE_STARTUP) {
	    MP_TRACE_g(fprintf(stderr, "error_log not open yet\n"));
	    XSRETURN_UNDEF;
	}
    }
    else { 
	if(r) 
	    s = r->server;
	else
	    s = perl_get_startup_server();
    }

    if(!s) croak("Apache::warn: no server_rec!");

    if(items > 1+i) {
	sv = newSV(0);
        do_join(sv, &sv_no, MARK+i, SP); /* $sv = join '', @_[1..$#_] */
        errstr = SvPV(sv,na);
    }
    else
        errstr = SvPV(ST(i),na);

    switch((ix = XSANY.any_i32)) {
	case 0:
	case 2:
	mod_perl_error(s, errstr);
	break;

	case 1:
	case 3:
	mod_perl_warn(s, errstr);
	break;

        default:
	mod_perl_error(s, errstr);
	break;
    }

    if(sv) SvREFCNT_dec(sv);

#methods for creating a CGI environment
void
cgi_env(r, ...)
    Apache	r

    PREINIT:
    char *key = NULL;
    I32 gimme = GIMME_V;

    PPCODE:
    if(items > 1) {
	key = SvPV(ST(1),na);
	if(items > 2) 
	    table_set(r->subprocess_env, key, SvPV(ST(2),na));
    }

    if((gimme == G_ARRAY) || (gimme == G_VOID)) {
        int i;
        array_header *arr  = perl_cgi_env_init(r);
        table_entry *elts = (table_entry *)arr->elts;
        if(gimme == G_ARRAY) {
	    for (i = 0; i < arr->nelts; ++i) {
	        if (!elts[i].key) continue;
	        PUSHelt(elts[i].key, elts[i].val, 0);
	    }
        }
    }
    else if(key) {
	char *value = (char *)table_get(r->subprocess_env, key);
	XPUSHs(value ? sv_2mortal((SV*)newSVpv(value, 0)) : &sv_undef);
    }
    else
        croak("Apache->cgi_env: need another argument in scalar context"); 
   

SV *
subprocess_env(r, key=NULL, ...)
    Apache    r
    char *key

    PREINIT:
    I32 gimme = GIMME_V;
 
    CODE:
    if((items == 1) && (gimme == G_VOID)) {
        (void)perl_cgi_env_init(r);
        XSRETURN_UNDEF;
    }
    TABLE_GET_SET(r->subprocess_env, FALSE);

    OUTPUT:
    RETVAL


#see httpd.h
#struct request_rec {

void
request(self, r=NULL)
    SV *self
    Apache r

    PPCODE: 
    self = self;
    if(items > 1) perl_request_rec(r);
    XPUSHs(perl_bless_request_rec(perl_request_rec(NULL)));

#  pool *pool;
#  conn_rec *connection;
#  server_rec *server;

void
connection(r)
    Apache	r
	
    PREINIT:
    char *packname = "Apache::Connection";
  
    CODE:
    ST(0) = sv_newmortal();
    sv_setref_pv(ST(0), packname, (void*)r->connection);

void
server(rsv)
    SV *rsv
	
    PREINIT:
    char *packname = "Apache::Server";
    server_rec *s;
    request_rec *r;

    CODE:
    if (SvROK(rsv) && (r = sv2request_rec(rsv, "Apache", cv))) {
	s = r->server;
    }
    else {
	if(!(s = perl_get_startup_server()))
	   croak("Apache->server: no startup server_rec available");
    }

    ST(0) = sv_newmortal();
    sv_setref_pv(ST(0), packname, (void*)s);

#  request_rec *next;		/* If we wind up getting redirected,
#				 * pointer to the request we redirected to.
#				 */
#  request_rec *prev;		/* If this is an internal redirect,
#				 * pointer to where we redirected *from*.
#				 */
  
#  request_rec *main;		/* If this is a sub_request (see request.h) 
#				 * pointer back to the main request.
#				 */

# ...
#  /* Info about the request itself... we begin with stuff that only
#   * protocol.c should ever touch...
#   */
  
#  char *the_request;		/* First line of request, so we can log it */
#  int assbackwards;		/* HTTP/0.9, "simple" request */
#  int proxyreq;                 /* A proxy request */
#  int header_only;		/* HEAD request, as opposed to GET */

#  char *protocol;		/* Protocol, as given to us, or HTTP/0.9 */
#  char *hostname;		/* Host, as set by full URI or Host: */
#  int hostlen;			/* Length of http://host:port in full URI */

#  char *status_line;		/* Status line, if set by script */
#  int status;			/* In any case */

void
main(r)
    Apache   r

    CODE:
    if(r->main != NULL)
 	ST(0) = perl_bless_request_rec((request_rec *)r->main);
    else
        ST(0) = &sv_undef;

void
prev(r)
    Apache   r

    CODE:
    if(r->prev != NULL)
 	ST(0) = perl_bless_request_rec((request_rec *)r->prev);
    else
        ST(0) = &sv_undef;

void
next(r)
    Apache   r

    CODE:
    if(r->next != NULL)
 	ST(0) = perl_bless_request_rec((request_rec *)r->next);
    else
        ST(0) = &sv_undef;

Apache
last(r)
    Apache   r

    CODE:
    for(RETVAL=r; RETVAL->next; RETVAL=RETVAL->next)
        continue;

    OUTPUT:
    RETVAL

int
is_initial_req(r)
    Apache   r

int 
is_main(r)
    Apache   r

    CODE:
    if(r->main != NULL) RETVAL = 0;
    else RETVAL = 1;
       
    OUTPUT:
    RETVAL

char *
the_request(r)
    Apache   r

    CODE:
    RETVAL = r->the_request;

    OUTPUT:
    RETVAL

int
proxyreq(r, ...)
    Apache   r

    CODE:
    RETVAL = r->proxyreq;

    if(items > 1)
        r->proxyreq = (int)SvIV(ST(1));

    OUTPUT:
    RETVAL

int
header_only(r)
    Apache   r

    CODE:
    RETVAL = r->header_only;

    OUTPUT:
    RETVAL

char *
protocol(r)
    Apache	r

    CODE:
    RETVAL = r->protocol;

    OUTPUT:
    RETVAL

char *
hostname(r)
    Apache	r

    CODE:
    RETVAL = (char *)r->hostname;

    OUTPUT:
    RETVAL

int
status(r, ...)
    Apache	r

    CODE:
    RETVAL = r->status;

    if(items > 1)
        r->status = (int)SvIV(ST(1));

    OUTPUT:
    RETVAL

time_t
request_time(r)
    Apache	r

    CODE:
    RETVAL = r->request_time;

    OUTPUT:
    RETVAL

char *
status_line(r, ...)
    Apache	r

    CODE:
    RETVAL = (char *)r->status_line;

    if(items > 1)
        r->status_line = pstrdup(r->pool, (char *)SvPV(ST(1),na));

    OUTPUT:
    RETVAL
  
#  /* Request method, two ways; also, protocol, etc..  Outside of protocol.c,
#   * look, but don't touch.
#   */
  
#  char *method;			/* GET, HEAD, POST, etc. */
#  int method_number;		/* M_GET, M_POST, etc. */

#  int sent_bodyct;		/* byte count in stream is for body */
#  long bytes_sent;		/* body byte count, for easy access */

char *
method(r, ...)
    Apache	r

    CODE:
    RETVAL = r->method;

    if(items > 1)
        r->method = pstrdup(r->pool, (char *)SvPV(ST(1),na));

    OUTPUT:
    RETVAL

int
method_number(r, ...)
    Apache	r

    CODE:
    RETVAL = r->method_number;

    if(items > 1)
        r->method_number = (int)SvIV(ST(1));

    OUTPUT:
    RETVAL

long
bytes_sent(r, ...)
    Apache	r

    PREINIT:
    request_rec *last;

    CODE:

    for(last=r; last->next; last=last->next)
        continue;

    RETVAL = last->bytes_sent;

    if(items > 1)
        r->bytes_sent = (long)SvIV(ST(1));

    OUTPUT:
    RETVAL

long
read_length(r, len=-1)
    Apache	r
    long len

    CODE:
    RETVAL = r->read_length;
    if(len > -1)
        r->read_length = len;

#    /* MIME header environments, in and out.  Also, an array containing
#   * environment variables to be passed to subprocesses, so people can
#   * write modules to add to that environment.
#   *
#   * The difference between headers_out and err_headers_out is that the
#   * latter are printed even on error, and persist across internal redirects
#   * (so the headers printed for ErrorDocument handlers will have them).
#   *
#   * The 'notes' table is for notes from one module to another, with no
#   * other set purpose in mind...
#   */
  
#  table *headers_in;
#  table *headers_out;
#  table *err_headers_out;
#  table *subprocess_env;
#  table *notes;

#  char *content_type;		/* Break these out --- we dispatch on 'em */
#  char *handler;		/* What we *really* dispatch on           */

#  char *content_encoding;
#  char *content_language;
  
#  int no_cache;

SV *
header_in(r, key, ...)
    Apache	r
    char *key

    CODE:
    TABLE_GET_SET(r->headers_in, TRUE);

    OUTPUT:
    RETVAL

void
headers_in(r)
    Apache	r

    PREINIT:
    
    int i;
    array_header *hdrs_arr;
    table_entry  *hdrs;

    PPCODE:
    if(GIMME == G_SCALAR) {
	ST(0) = mod_perl_tie_table(r->headers_in); 
	XSRETURN(1); 	
    }
    hdrs_arr = table_elts (r->headers_in);
    hdrs = (table_entry *)hdrs_arr->elts;

    for (i = 0; i < hdrs_arr->nelts; ++i) {
	if (!hdrs[i].key) continue;
	PUSHelt(hdrs[i].key, hdrs[i].val, 0);
    }

SV *
header_out(r, key, ...)
    Apache	r
    char *key

    CODE:
    TABLE_GET_SET(r->headers_out, TRUE);

    OUTPUT:
    RETVAL

SV *
cgi_header_out(r, key, ...)
    Apache	r
    char *key

    PREINIT:
    char *val;

    CODE:
    if((val = (char *)table_get(r->headers_out, key))) 
	RETVAL = newSVpv(val, 0);
    else
        RETVAL = newSV(0);

    SvTAINTED_on(RETVAL);

    if(items > 2) {
	int status = 302;
	val = SvPV(ST(2),na);
        if(!strncasecmp(key, "Content-type", 12)) {
	    r->content_type = pstrdup (r->pool, val);
	}
        else if(!strncasecmp(key, "Status", 6)) {
            sscanf(val, "%d", &r->status);
            r->status_line = pstrdup(r->pool, val);
        }
        else if(!strncasecmp(key, "Location", 8)) {
	    if (val && val[0] == '/' && r->status == 200) {
		/* not sure if this is quite right yet */
		/* set $Apache::DoInternalRedirect++ to test */
		if(DO_INTERNAL_REDIRECT) {
		    r->method = pstrdup(r->pool, "GET");
		    r->method_number = M_GET;

		    table_unset(r->headers_in, "Content-Length");

		    status = 200;
		    perl_soak_script_output(r);
		    internal_redirect_handler(val, r);
		}
	    }
	    table_set (r->headers_out, key, val);
	    r->status = status;
        }   
        else if(!strncasecmp(key, "Content-Length", 14)) {
	    table_set (r->headers_out, key, val);
        }   
        else if(!strncasecmp(key, "Transfer-Encoding", 17)) {
	    table_set (r->headers_out, key, val);
        }   

#The HTTP specification says that it is legal to merge duplicate
#headers into one.  Some browsers that support Cookies don't like
#merged headers and prefer that each Set-Cookie header is sent
#separately.  Lets humour those browsers.

	else if(!strncasecmp(key, "Set-Cookie", 10)) {
	    table_add(r->err_headers_out, key, val);
	}
        else {
	    table_merge (r->err_headers_out, key, val);
        }
    }

void
headers_out(r)
    Apache	r

    PREINIT:
    int i;
    array_header *hdrs_arr;
    table_entry  *hdrs;

    PPCODE:
    if(GIMME == G_SCALAR) {
	ST(0) = mod_perl_tie_table(r->headers_out); 
	XSRETURN(1); 	
    }
    hdrs_arr = table_elts (r->headers_out);
    hdrs = (table_entry *)hdrs_arr->elts;
    for (i = 0; i < hdrs_arr->nelts; ++i) {
	if (!hdrs[i].key) continue;
	PUSHelt(hdrs[i].key, hdrs[i].val, 0);
    }

SV *
err_header_out(r, key, ...)
    Apache	r
    char *key

    CODE:
    TABLE_GET_SET(r->err_headers_out, TRUE);

    OUTPUT:
    RETVAL

void
err_headers_out(r, ...)
    Apache	r

    PREINIT:
    int i;
    array_header *hdrs_arr;
    table_entry  *hdrs;

    PPCODE:
    if(GIMME == G_SCALAR) {
	ST(0) = mod_perl_tie_table(r->err_headers_out); 
	XSRETURN(1); 	
    }
    hdrs_arr = table_elts (r->err_headers_out);
    hdrs = (table_entry *)hdrs_arr->elts;

    for (i = 0; i < hdrs_arr->nelts; ++i) {
	if (!hdrs[i].key) continue;
	PUSHelt(hdrs[i].key, hdrs[i].val, 0);
    }

SV *
notes(r, key=NULL, ...)
    Apache    r
    char *key

    CODE:
    TABLE_GET_SET(r->notes, FALSE);

    OUTPUT:
    RETVAL

char *
content_type(r, ...)
    Apache	r

    CODE:
    RETVAL = (char *)r->content_type;

    if(items > 1)
        r->content_type = pstrdup(r->pool, SvPV(ST(1), na));
  
    OUTPUT:
    RETVAL

char *
handler(r, ...)
    Apache	r

    CODE:
    RETVAL = (char *)r->handler;

    if(items > 1)
        r->handler = (ST(1) == &sv_undef) ? 
	NULL : pstrdup(r->pool, SvPV(ST(1),na));
  
    OUTPUT:
    RETVAL

char *
content_encoding(r, ...)
    Apache	r

    CODE:
    RETVAL = (char *)r->content_encoding;

    if(items > 1)
      r->content_encoding = pstrdup(r->pool, SvPV(ST(1),na));

    OUTPUT:
    RETVAL

char *
content_language(r, ...)
    Apache	r

    CODE:
    RETVAL = (char *)r->content_language;

    if(items > 1)
        r->content_language = pstrdup(r->pool, SvPV(ST(1),na));

    OUTPUT:
    RETVAL

void
content_languages(r, avrv=Nullsv)
    Apache	r
    SV *avrv

    PREINIT:   
    I32 gimme = GIMME_V;

    CODE:
    if(avrv && SvROK(avrv))
        r->content_languages = avrv2array_header(avrv, r->pool);

    if(gimme != G_VOID)
        ST(0) = array_header2avrv(r->content_languages);
				   
int
no_cache(r, ...)
    Apache	r

    CODE: 
    RETVAL = r->no_cache;

    if(items > 1)
        r->no_cache = (int)SvIV(ST(1));

    OUTPUT:
    RETVAL

#  /* What object is being requested (either directly, or via include
#   * or content-negotiation mapping).
#   */

#  char *uri;                    /* complete URI for a proxy req, or
#                                   URL path for a non-proxy req */
#  char *filename;
#  char *path_info;
#  char *args;			/* QUERY_ARGS, if any */
#  struct stat finfo;		/* ST_MODE set to zero if no such file */

char *
uri(r, ...)
    Apache	r

    CODE:
    RETVAL = r->uri;

    if(items > 1)
        r->uri = pstrdup(r->pool, SvPV(ST(1),na));

    OUTPUT:
    RETVAL

char *
filename(r, ...)
    Apache	r

    CODE:
    RETVAL = r->filename;

    if(items > 1) {
        r->filename = pstrdup(r->pool, SvPV(ST(1),na));
#ifndef WIN32
	stat(r->filename, &r->finfo);
#endif
    }
    OUTPUT:
    RETVAL

char *
path_info(r, ...)
    Apache	r

    CODE:
    RETVAL = r->path_info;

    if(items > 1)
        r->path_info = pstrdup(r->pool, SvPV(ST(1),na));

    OUTPUT:
    RETVAL

void
query_string(r, ...)
    Apache	r

    PREINIT:
    SV *sv = sv_newmortal();

    PPCODE: 
    if(r->args)
	sv_setpv(sv, r->args);
    SvTAINTED_on(sv);
    XPUSHs(sv);

    if(items > 1)
        r->args = pstrdup(r->pool, (char *)SvPV(ST(1),na));

#  /* Various other config info which may change with .htaccess files
#   * These are config vectors, with one void* pointer for each module
#   * (the thing pointed to being the module's business).
#   */
  
#  void *per_dir_config;		/* Options set in config files, etc. */

char *
location(r)
    Apache  r

    CODE:
    if(r->per_dir_config) {				   
	dPPDIR;
        RETVAL = cld->location;
    }
    else XSRETURN_UNDEF;

    OUTPUT:
    RETVAL

SV *
dir_config(r, key=NULL, ...)
    Apache  r
    char *key

    PREINIT:
    perl_dir_config *c;

    CODE:
    if(r->per_dir_config) {				   
        c = get_module_config(r->per_dir_config, &perl_module);
        TABLE_GET_SET(c->vars, FALSE);
    }
    else XSRETURN_UNDEF;
 
    OUTPUT:
    RETVAL
   
#  void *request_config;		/* Notes on *this* request */

#/*
# * a linked list of the configuration directives in the .htaccess files
# * accessed by this request.
# * N.B. always add to the head of the list, _never_ to the end.
# * that way, a sub request's list can (temporarily) point to a parent's list
# */
#  const struct htaccess_result *htaccess;
#};

Apache::SubRequest
lookup_uri(r, uri)
    Apache r
    char *uri

    CODE:
    RETVAL = sub_req_lookup_uri(uri,r);

    OUTPUT:
    RETVAL

Apache::SubRequest
lookup_file(r, file)
    Apache r
    char *file

    CODE:
    RETVAL = sub_req_lookup_file(file,r);

    OUTPUT:
    RETVAL

MODULE = Apache  PACKAGE = Apache::SubRequest

BOOT:
    av_push(perl_get_av("Apache::SubRequest::ISA",TRUE), newSVpv("Apache",6));

void
DESTROY(r)
    Apache::SubRequest r

    CODE:
    destroy_sub_req(r);
    MP_TRACE_g(fprintf(stderr, 
	    "Apache::SubRequest::DESTROY(0x%lx)\n", (unsigned long)r));

int
run(r)
    Apache::SubRequest r

    CODE:
    RETVAL = run_sub_req(r);

    OUTPUT:
    RETVAL

#/* Things which are per connection
# */

#struct conn_rec {

MODULE = Apache  PACKAGE = Apache::Connection

PROTOTYPES: DISABLE

#  pool *pool;
#  server_rec *server;
  
#  /* Information about the connection itself */
  
#  BUFF *client;			/* Connetion to the guy */
#  int aborted;			/* Are we still talking? */
  
#  /* Who is the client? */
  
#  struct sockaddr_in local_addr; /* local address */
#  struct sockaddr_in remote_addr;/* remote address */
#  char *remote_ip;		/* Client's IP address */
#  char *remote_host;		/* Client's DNS name, if known.
#                                 * NULL if DNS hasn't been checked,
#                                 * "" if it has and no address was found.
#                                 * N.B. Only access this though
#				 * get_remote_host() */

int
aborted(conn)
    Apache::Connection	conn

    CODE:
    RETVAL = conn->aborted || (conn->client && (conn->client->fd < 0));

    OUTPUT:
    RETVAL

SV *
local_addr(conn)
    Apache::Connection        conn

    CODE:
    RETVAL = newSVpv((char *)&conn->local_addr,
		     sizeof conn->local_addr);

    OUTPUT:
    RETVAL

SV *
remote_addr(conn)
    Apache::Connection        conn

    CODE:
    RETVAL = newSVpv((char *)&conn->remote_addr,
                      sizeof conn->remote_addr);

    OUTPUT:
    RETVAL

char *
remote_ip(conn)
    Apache::Connection	conn

    CODE:
    RETVAL = conn->remote_ip;

    OUTPUT:
    RETVAL

char *
remote_host(conn)
    Apache::Connection	conn

    CODE:
    RETVAL = conn->remote_host;

    OUTPUT:
    RETVAL

#  char *remote_logname;		/* Only ever set if doing_rfc931
#                                 * N.B. Only access this through
#				 * get_remote_logname() */
#    char *user;			/* If an authentication check was made,
#				 * this gets set to the user name.  We assume
#				 * that there's only one user per connection(!)
#				 */
#  char *auth_type;		/* Ditto. */

char *
remote_logname(conn)
    Apache::Connection	conn

    CODE:
    RETVAL = conn->remote_logname;

    OUTPUT:
    RETVAL

char *
user(conn, ...)
    Apache::Connection	conn

    CODE:
    RETVAL = conn->user;

    if(items > 1)
        conn->user = pstrdup(conn->pool, (char *)SvPV(ST(1),na));

    OUTPUT:
    RETVAL

char *
auth_type(conn, ...)
    Apache::Connection	conn

    CODE:
    RETVAL = conn->auth_type;

    if(items > 1)
        conn->auth_type = pstrdup(conn->pool, (char *)SvPV(ST(1),na));

    OUTPUT:
    RETVAL

#  int keepalive;		/* Are we using HTTP Keep-Alive? */
#  int keptalive;		/* Did we use HTTP Keep-Alive? */
#  int keepalives;		/* How many times have we used it? */
#};

#/* Per-vhost config... */

#struct server_rec {

MODULE = Apache  PACKAGE = Apache::Server

PROTOTYPES: DISABLE

#  server_rec *next;
  
#  /* Full locations of server config info */
  
#  char *srm_confname;
#  char *access_confname;
  
#  /* Contact information */
  
#  char *server_admin;
#  char *server_hostname;
#  short port;                    /* for redirects, etc. */

char *
server_admin(server, ...)
    Apache::Server	server

    CODE:
    RETVAL = server->server_admin;

    OUTPUT:
    RETVAL

char *
server_hostname(server)
    Apache::Server	server

    CODE:
    RETVAL = server->server_hostname;

    OUTPUT:
    RETVAL

short
port(server, ...)
    Apache::Server	server

    CODE:
    RETVAL = server->port;

    if(items > 1)
        server->port = (short)SvIV(ST(1));

    OUTPUT:
    RETVAL
  
#  /* Log files --- note that transfer log is now in the modules... */
  
#  char *error_fname;
#  FILE *error_log;

#  /* Module-specific configuration for server, and defaults... */

#  int is_virtual;               /* true if this is the virtual server */
#  void *module_config;		/* Config vector containing pointers to
#				 * modules' per-server config structures.
#				 */
#  void *lookup_defaults;	/* MIME type info, etc., before we start
#				 * checking per-directory info.
#				 */
#  /* Transaction handling */

#  struct in_addr host_addr;	/* The bound address, for this server */
#  short host_port;              /* The bound port, for this server */
#  int timeout;			/* Timeout, in seconds, before we give up */
#  int keep_alive_timeout;	/* Seconds we'll wait for another request */
#  int keep_alive_max;		/* Maximum requests per connection */
#  int keep_alive;		/* Use persistent connections? */

#  char *names;			/* Wildcarded names for HostAlias servers */
#  char *virthost;		/* The name given in <VirtualHost> */

int
is_virtual(server)
    Apache::Server	server

    CODE:
    RETVAL = server->is_virtual;

    OUTPUT:
    RETVAL

char *
names(server)
    Apache::Server	server

    CODE:
#if MODULE_MAGIC_NUMBER < 19980305
    RETVAL = server->names;
#else
    RETVAL = ""; /* XXX: fixme */			   
#endif

    OUTPUT:
    RETVAL				   
