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

SV *array_header2avrv(array_header *arr)
{
    AV *av;
    int i;

    iniAV(av);
    if(arr) {
	for (i = 0; i < arr->nelts; i++) {
	    av_push(av, newSVpv(((char **) arr->elts)[i], 0));
	}
    }
    return newRV_noinc((SV*)av);
}

array_header *avrv2array_header(SV *avrv, pool *p)
{
    AV *av = (AV*)SvRV(avrv);
    I32 i;
    array_header *arr = make_array(p, AvFILL(av)-1, sizeof(char *));

    for(i=0; i<=AvFILL(av); i++) {
	SV *sv = *av_fetch(av, i, FALSE);    
	char **new = (char **) push_array(arr);
	*new = pstrdup(p, SvPV(sv,na));
    }

    return arr;
}

/* same as Symbol::gensym() */
SV *mod_perl_gensym (char *pack)
{
    GV *gv = newGVgen(pack);
    SV *rv = newRV((SV*)gv);
    (void)hv_delete(gv_stashpv(pack, TRUE), 
		    GvNAME(gv), GvNAMELEN(gv), G_DISCARD);
    return rv;
}

SV *mod_perl_tie_table(table *t)
{
    HV *hv;
    SV *sv = sv_newmortal();
    iniHV(hv);
    sv_setref_pv(sv, "Apache::Table", (void*)t);
    perl_qrequire_module("Apache::Tie");
    perl_tie_hash(hv, "Apache::TieHashTable", sv);
    return newRV_noinc((SV*)hv);
}

void perl_tie_hash(HV *hv, char *class, SV *sv)
{
    dSP;
    SV *obj, *varsv = (SV*)hv;
    char *methname = "TIEHASH";
    
    ENTER;
    SAVETMPS;
    PUSHMARK(sp);
    XPUSHs(sv_2mortal(newSVpv(class,0)));
    if(sv) XPUSHs(sv);
    PUTBACK;
    perl_call_method(methname, G_EVAL | G_SCALAR);
    if(SvTRUE(ERRSV)) warn("perl_tie_hash: %s", SvPV(ERRSV,na));

    SPAGAIN;

    obj = POPs;
    sv_unmagic(varsv, 'P');
    sv_magic(varsv, obj, 'P', Nullch, 0);

    PUTBACK;
    FREETMPS;
    LEAVE; 
}

/* execute END blocks */

void perl_run_blocks(I32 oldscope, AV *list)
{
    STRLEN len;
    I32 i;
    dTHR;

    for(i=0; i<=AvFILL(list); i++) {
	CV *cv = (CV*)*av_fetch(list, i, FALSE);
	SV* atsv = ERRSV;

	MARK_WHERE("END block", (SV*)cv);
	PUSHMARK(stack_sp);
	perl_call_sv((SV*)cv, G_EVAL|G_DISCARD);
	UNMARK_WHERE;
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
	    MP_TRACE_g(fprintf(stderr, "endav is empty for %s\n", r->uri));
	    return;
	}
	av = (AV*)SvRV(entry);
	av_clear(av);
	SvREFCNT_dec((SV*)av);
	(void)hv_delete(mod_perl_endhv, key, klen, G_DISCARD);
	MP_TRACE_g(fprintf(stderr, 
			 "clearing END blocks for package `%s' (uri=%s)\n",
			 key, r->uri)); 
    }
}

void perl_run_rgy_endav(char *s) 
{
    SV *rgystash = perl_get_sv("Apache::Registry::curstash", FALSE);
    AV *rgyendav = Nullav;
    STRLEN klen;
    char *key;
    dTHR;

    if(!rgystash || !SvTRUE(rgystash)) {
	MP_TRACE_g(fprintf(stderr, 
        "Apache::Registry::curstash not set, can't run END blocks for %s\n",
			 s));
	return;
    }

    key = SvPV(rgystash,klen);

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

    MP_TRACE_g(fprintf(stderr, 
	     "running %d END blocks for %s\n", rgyendav ? (int)AvFILL(rgyendav)+1 : 0, s));
    if((endav = rgyendav)) 
	perl_run_blocks(scopestack_ix, endav);
    if(rgyendav)
	hv_store(mod_perl_endhv, key, klen, (SV*)newRV((SV*)rgyendav), FALSE);
    
    sv_setpv(rgystash,"");
}

void perl_run_endav(char *s)
{
    dTHR;
    I32 n = 0;
    if(endav)
	n = AvFILL(endav)+1;

    MP_TRACE_g(fprintf(stderr, "running %d END blocks for %s\n", 
		       (int)n, s));
    if(endav) {
	curstash = defstash;
	call_list(scopestack_ix, endav);
    }
}

static I32
errgv_empty_set(IV ix, SV* sv)
{ 
    sv_setpv(sv, "");
    return TRUE;
}

void perl_call_halt(int status)
{
    dTHR;
    struct ufuncs umg;
    int is_http_code = 
	((status >= 100) && (status < 600) && ERRSV_CAN_BE_HTTP);

    umg.uf_val = errgv_empty_set;
    umg.uf_set = errgv_empty_set;
    umg.uf_index = (IV)0;
    
    if(is_http_code) {
	croak("%d\n", status);
    }
    else {
	sv_magic(ERRSV, Nullsv, 'U', (char*) &umg, sizeof(umg));

	ENTER;
	SAVESPTR(diehook);
	diehook = Nullsv; 
	croak("");
	LEAVE; /* we don't get this far, but croak() will rewind */

	sv_unmagic(ERRSV, 'U');
    }
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
	MP_TRACE_g(fprintf(stderr, "reloading %s\n", key));
    }

    LEAVE;
}

I32 perl_module_is_loaded(char *name)
{
    I32 retval = FALSE;
    SV *key = perl_module2file(name);
    if((key && hv_exists_ent(GvHV(incgv), key, FALSE)))
	retval = TRUE;
    if(key)
	SvREFCNT_dec(key);
    return retval;
}

SV *perl_module2file(char *name)
{
    SV *sv = newSVpv(name,0);
    char *s;
    for (s = SvPVX(sv); *s; s++) {
	if (*s == ':' && s[1] == ':') {
	    *s = '/';
	    Move(s+2, s+1, strlen(s+2)+1, char);
	    --SvCUR(sv);
	}
    }
    sv_catpvn(sv, ".pm", 3);
    return sv;
}

int perl_require_module(char *mod, server_rec *s)
{
    dTHR;
    SV *sv = sv_newmortal();
    sv_setpvn(sv, "require ", 8);
    MP_TRACE_d(fprintf(stderr, "loading perl module '%s'...", mod)); 
    sv_catpv(sv, mod);
    perl_eval_sv(sv, G_DISCARD);
    if(s) {
	if(perl_eval_ok(s) != OK) {
	    MP_TRACE_d(fprintf(stderr, "not ok\n"));
	    return -1;
	}
    }
    else if(SvTRUE(ERRSV)) {
	MP_TRACE_d(fprintf(stderr, "not ok\n"));
	return -1;
    }

    MP_TRACE_d(fprintf(stderr, "ok\n"));
    return 0;
}

/* faster than require_module, 
 * used when we're already in an eval context
 */
void perl_qrequire_module(char *name) 
{
    OP *mod;
    SV *key = perl_module2file(name);
    if((key && hv_exists_ent(GvHV(incgv), key, FALSE)))
	return;
    mod = newSVOP(OP_CONST, 0, key);
    /*mod->op_private |= OPpCONST_BARE;*/
    utilize(TRUE, start_subparse(FALSE, 0), Nullop, mod, Nullop);
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
	MP_TRACE_d(fprintf(stderr, "no Perl script to load\n"));
	return OK;
    }

    MP_TRACE_d(fprintf(stderr, "attempting to require `%s'\n", script));
    dowarn = my_warn;
    curstash = defstash;
    perl_do_file(script);
    dowarn = old_warn;
    return perl_eval_ok(s);
} 

array_header *perl_cgi_env_init(request_rec *r)
{
    table *envtab = r->subprocess_env; 
    char *tz = NULL; 

    add_common_vars(r); 
    add_cgi_vars(r); 

    if ((tz = getenv("TZ")) != NULL)
	table_set(envtab, "TZ", tz);

    table_set(envtab, "PATH", DEFAULT_PATH);
    table_set(envtab, "GATEWAY_INTERFACE", PERL_GATEWAY_INTERFACE);

    return table_elts(envtab);
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
    MP_TRACE_g(fprintf(stderr, 
		     "perl_init_ids: uid=%d, euid=%d, gid=%d, egid=%d\n",
		     uid, euid, gid, egid));
#endif
}

int perl_eval_ok(server_rec *s)
{
    dTHR;
    SV *sv = ERRSV;
    if(SvTRUE(sv)) {
	MP_TRACE_g(fprintf(stderr, "perl_eval error: %s\n", SvPV(sv,na)));
	mod_perl_error(s, SvPV(sv, na));
	return -1;
    }
    return 0;
}

int perl_sv_is_http_code(SV *errsv, int *status) 
{
    int i=0, http_code=0, retval = FALSE;
    char *errpv;
    char cpcode[4];

    if(!SvTRUE(errsv) || !ERRSV_CAN_BE_HTTP)
	return FALSE;

    errpv = SvPVX(errsv);

    for(i=0;i<=2;i++) {
	if(i >= SvCUR(errsv)) 
	    break;
	if(isDIGIT(SvPVX(errsv)[i])) 
	    http_code++;
	else
	    http_code--;
    }

    /* we've looked at the first 3 characters of $@
     * if they're not all digits, $@ is not an HTTP code
     */
    if(http_code != 3) {
	MP_TRACE_g(fprintf(stderr, 
			 "mod_perl: $@ doesn't look like an HTTP code `%s'\n", 
			 errpv));
	return FALSE;
    }

    /* nothin but 3 digits */
    if(SvCUR(errsv) == http_code)
	return TRUE;

    ap_cpystrn((char *)cpcode, errpv, 4);

    MP_TRACE_g(fprintf(stderr, 
		     "mod_perl: possible $@ HTTP code `%s' (cp=`%s')\n", 
		     errpv,cpcode));

    if((SvCUR(errsv) == 4) && (*(SvEND(errsv) - 1) == '\n')) {
	/* nothin but 3 digit code and \n */
	retval = TRUE;
    }
    else {
	char *tmp = errpv;
	tmp += 3;
#ifndef PERL_MARK_WHERE
	if(strNE(SvPVX(GvSV(curcop->cop_filegv)), "-e")) {
	    SV *fake = newSV(0);
	    sv_setpv(fake, ""); /* avoid -w warning */
	    sv_catpvf(fake, " at %_ line ", GvSV(curcop->cop_filegv));

	    if(strnEQ(SvPVX(fake), tmp, SvCUR(fake))) 
		/* $@ is nothing but 3 digit code and the mess die tacks on */
		retval = TRUE;

	    SvREFCNT_dec(fake);
	}
#endif
	if(!retval && strnEQ(tmp, " at ", 4) && instr(errpv, " line "))
	    /* well, close enough */
	    retval = TRUE;
    }

    if(retval == TRUE) {
    	*status = atoi(cpcode);
	MP_TRACE_g(fprintf(stderr, 
			 "mod_perl: $@ is an HTTP code `%d'\n", *status));
    }

    return retval;
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

#ifdef PERL_MARK_WHERE
/* XXX find the right place for this! */
static SV *perl_sv_name(SV *svp)
{
    SV *sv = Nullsv;
    SV *RETVAL = Nullsv;

    if(svp && SvROK(svp) && (sv = SvRV(svp))) {
	switch(SvTYPE(sv)) {
	case SVt_PVCV:
	    RETVAL = newSV(0);
	    gv_fullname(RETVAL, CvGV(sv));
	    break;

	default:
	    break;
	}
    }
    else if(svp && SvPOK(svp)) {
	RETVAL = newSVsv(svp);
    }

    return RETVAL;
}

void mod_perl_mark_where(char *where, SV *sub)
{
    dTHR;
    SV *name = Nullsv;
    if(curcop->cop_line) {
#if 0
	fprintf(stderr, "already know where: %s line %d\n",
		SvPV(GvSV(curcop->cop_filegv),na), curcop->cop_line);
#endif
	return;
    }

    SAVESPTR(curcop->cop_filegv);
    SAVEI16(curcop->cop_line);

    if(sub) 
	name = perl_sv_name(sub);

    sv_setpv(GvSV(curcop->cop_filegv), "");
    sv_catpvf(GvSV(curcop->cop_filegv), "%s subroutine `%_'", where, name);
    curcop->cop_line = 1;

    if(name)
	SvREFCNT_dec(name);
}
#endif

#if MODULE_MAGIC_NUMBER < 19971226
char *ap_cpystrn(char *dst, const char *src, size_t dst_size)
{

    char *d, *end;

    if (!dst_size)
        return (dst);

    d = dst;
    end = dst + dst_size - 1;

    for (; d < end; ++d, ++src) {
	if (!(*d = *src)) {
	    return (d);
	}
    }

    *d = '\0';	/* always null terminate */

    return (d);
}

#endif

