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

#include "mod_perl.h"

static HV *mod_perl_endhv = Nullhv;
static int set_ids = 0;

void perl_util_cleanup(void)
{
    hv_undef(mod_perl_endhv);
    SvREFCNT_dec((SV*)mod_perl_endhv);
    mod_perl_endhv = Nullhv;

    set_ids = 0;
}

#ifdef PERL_SECTIONS
void perl_tie_hash(HV *hv, char *class)
{
    dSP;
    SV *obj, *varsv = (SV*)hv;
    char *methname = "TIEHASH";
    
    ENTER;
    SAVETMPS;
    PUSHMARK(sp);
    XPUSHs(sv_2mortal(newSVpv(class,0)));
    PUTBACK;
    perl_call_method(methname, G_EVAL | G_SCALAR);
    SPAGAIN;

    obj = POPs;
    sv_unmagic(varsv, 'P');
    sv_magic(varsv, obj, 'P', Nullch, 0);

    PUTBACK;
    FREETMPS;
    LEAVE; 
}
#endif

/* execute END blocks */

void perl_run_blocks(I32 oldscope, AV *list)
{
    STRLEN len;
    I32 i;
    dTHR;

    for(i=0; i<=AvFILL(list); i++) {
	CV *cv = (CV*)*av_fetch(list, i, FALSE);
	SV* atsv = ERRSV;

	PUSHMARK(stack_sp);
	perl_call_sv((SV*)cv, G_EVAL|G_DISCARD);
	(void)SvPV(atsv, len);
	if (len) {
	    if (list == beginav)
		sv_catpv(atsv, "BEGIN failed--compilation aborted");
	    else
		sv_catpv(atsv, "END failed--cleanup aborted");
	    while (scopestack_ix > oldscope)
		LEAVE;
	}
    }
}

void mod_perl_clear_rgy_endav(request_rec *r, SV *sv)
{
    STRLEN klen;
    char *key;

    if(!mod_perl_endhv) return;

    key = SvPV(sv,klen);
    if(hv_exists(mod_perl_endhv, key, klen)) {
	SV *entry = *hv_fetch(mod_perl_endhv, key, klen, FALSE);
	AV *av;
	if(!SvTRUE(entry) && !SvROK(entry)) {
	    MP_TRACE(fprintf(stderr, "endav is empty for %s\n", r->uri));
	    return;
	}
	av = (AV*)SvRV(entry);
	av_clear(av);
	SvREFCNT_dec((SV*)av);
	(void)hv_delete(mod_perl_endhv, key, klen, G_DISCARD);
	MP_TRACE(fprintf(stderr, 
			 "clearing END blocks for package `%s' (uri=%s)\n",
			 key, r->uri)); 
    }
}

void perl_run_rgy_endav(char *s) 
{
    SV *rgystash = perl_get_sv("Apache::Registry::curstash", TRUE);
    AV *rgyendav = Nullav;
    STRLEN klen;
    char *key = SvPV(rgystash,klen);
    dTHR;

    if(!klen) {
	MP_TRACE(fprintf(stderr, 
        "Apache::Registry::curstash not set, can't run END blocks for %s\n",
			 s));
	return;
    }

    if(mod_perl_endhv == Nullhv)
	mod_perl_endhv = newHV();
    else if(hv_exists(mod_perl_endhv, key, klen)) {
	SV *entry = *hv_fetch(mod_perl_endhv, key, klen, FALSE);
	if(SvTRUE(entry) && SvROK(entry)) 
	    rgyendav = (AV*)SvRV(entry);
    }

    if(endav) {
	I32 i;
	if(rgyendav == Nullav)
	    rgyendav = newAV();

	if(AvFILL(rgyendav) > -1)
	    av_clear(rgyendav);
	else
	    av_extend(rgyendav, AvFILL(endav));

	for(i=0; i<=AvFILL(endav); i++) {
	    SV **svp = av_fetch(endav, i, FALSE);
	    av_store(rgyendav, i, (SV*)newRV((SV*)*svp));
	}
    }

    MP_TRACE(fprintf(stderr, 
	     "running %d END blocks for %s\n", rgyendav ? AvFILL(rgyendav)+1 : 0, s));
    if((endav = rgyendav)) 
	perl_run_blocks(scopestack_ix, endav);
    if(rgyendav)
	hv_store(mod_perl_endhv, key, klen, (SV*)newRV((SV*)rgyendav), FALSE);
    
    sv_setpv(rgystash,"");
}

void perl_run_endav(char *s)
{
    dTHR;
    if(endav) {
	save_hptr(&curstash);
	curstash = defstash;
	MP_TRACE(fprintf(stderr, "running %d END blocks for %s\n", 
			 AvFILL(endav)+1, s));
	call_list(scopestack_ix, endav);
    }
}

static I32
errgv_empty_set(IV ix, SV* sv)
{ 
    sv_setpv(sv, "");
    return TRUE;
}

void perl_call_halt()
{
    dTHR;
    struct ufuncs umg;

    umg.uf_val = errgv_empty_set;
    umg.uf_set = errgv_empty_set;
    umg.uf_index = (IV)0;
                                                                  
    sv_magic(ERRSV, Nullsv, 'U', (char*) &umg, sizeof(umg));

    ENTER;
    SAVESPTR(diehook);
    diehook = Nullsv; 
    croak("");
    LEAVE;

    sv_unmagic(ERRSV, 'U');
}

void perl_reload_inc(void)
{
    SV *val;
    char *key;
    I32 klen;
    HV *orig_inc = GvHV(incgv);

    ENTER;

    save_hptr(&GvHV(incgv));
    GvHV(incgv) = Nullhv;
    SAVEI32(dowarn);
    dowarn = FALSE;

    (void)hv_iterinit(orig_inc);
    while((val = hv_iternextsv(orig_inc, &key, &klen))) {
	perl_require_pv(key);
	MP_TRACE(fprintf(stderr, "reloading %s\n", key));
    }

    LEAVE;
}

int perl_require_module(char *mod, server_rec *s)
{
    dTHR;
    SV *sv = sv_newmortal();
    sv_setpvn(sv, "require ", 8);
    MP_TRACE(fprintf(stderr, "loading perl module '%s'...", mod)); 
    sv_catpv(sv, mod);
    perl_eval_sv(sv, G_DISCARD);
    if(s) {
	if(perl_eval_ok(s) != OK) {
	    MP_TRACE(fprintf(stderr, "not ok\n"));
	    return -1;
	}
    }
    else if(SvTRUE(ERRSV)) {
	MP_TRACE(fprintf(stderr, "not ok\n"));
	return -1;
    }

    MP_TRACE(fprintf(stderr, "ok\n"));
    return 0;
}

void perl_do_file(char *pv)
{
    SV* sv = sv_newmortal();
    sv_setpv(sv, "require '");
    sv_catpv(sv, pv);
    sv_catpv(sv, "'");
    perl_eval_sv(sv, G_DISCARD);
    /*(void)hv_delete(GvHV(incgv), pv, strlen(pv), G_DISCARD);*/
}      

int perl_load_startup_script(server_rec *s, pool *p, char *script, I32 my_warn)
{
    dTHR;
    I32 old_warn = dowarn;

    if(!script) {
	MP_TRACE(fprintf(stderr, "no PerlScript to load\n"));
	return OK;
    }

    MP_TRACE(fprintf(stderr, "attempting to load `%s'\n", script));
    dowarn = my_warn;
    curstash = defstash;
    perl_do_file(script);
    dowarn = old_warn;
    return perl_eval_ok(s);
} 

void perl_clear_env(void)
{
    char *key; 
    I32 klen; 
    SV *val;
    HV *hv = (HV*)GvHV(envgv);

    sv_unmagic((SV*)hv, 'E');
    (void)hv_iterinit(hv); 
    while ((val = hv_iternextsv(hv, (char **) &key, &klen))) { 
	if((*key == 'G') && strEQ(key, "GATEWAY_INTERFACE"))
	    continue;
	else if((*key == 'M') && strnEQ(key, "MOD_PERL", 8))
	    continue;
	else if((*key == 'T') && strnEQ(key, "TZ", 2))
	    continue;
	(void)hv_delete(hv, key, klen, G_DISCARD);
    }
    sv_magic((SV*)hv, (SV*)envgv, 'E', Nullch, 0);
}

void mod_perl_init_ids(void)  /* $$, $>, $), etc */
{
    if(set_ids++) return;
    sv_setiv(GvSV(gv_fetchpv("$", TRUE, SVt_PV)), (I32)getpid());
#ifndef WIN32
    uid  = (int)getuid(); 
    euid = (int)geteuid(); 
    gid  = (int)getgid(); 
    egid = (int)getegid(); 
    MP_TRACE(fprintf(stderr, 
		     "perl_init_ids: uid=%d, euid=%d, gid=%d, egid=%d\n",
		     uid, euid, gid, egid));
#endif
}

int perl_eval_ok(server_rec *s)
{
    dTHR;
    SV *sv = ERRSV;
    if(SvTRUE(sv)) {
	MP_TRACE(fprintf(stderr, "perl_eval error: %s\n", SvPV(sv,na)));
	mod_perl_error(s, SvPV(sv, na));
	return -1;
    }
    return 0;
}

#ifndef PERLLIB_SEP
#define PERLLIB_SEP ':'
#endif

void perl_incpush(char *p)
{
    if(!p) return;

    while(p && *p) {
	SV *libdir = newSV(0);
	char *s;

	while(*p == PERLLIB_SEP) p++;

	if((s = strchr(p, PERLLIB_SEP)) != Nullch) {
	    sv_setpvn(libdir, p, (STRLEN)(s - p));
	    p = s + 1;
	}
	else {
	    sv_setpv(libdir, p);
	    p = Nullch;
	}
	av_push(GvAV(incgv), libdir);
    }
}
