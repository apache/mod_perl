#include "mod_perl.h"

int modperl_require_module(pTHX_ const char *pv, int logfailure)
{
    SV *sv;

    dSP;
    PUSHSTACKi(PERLSI_REQUIRE);
    PUTBACK;
    sv = sv_newmortal();
    sv_setpv(sv, "require ");
    sv_catpv(sv, pv);
    eval_sv(sv, G_DISCARD);
    SPAGAIN;
    POPSTACK;

    if (SvTRUE(ERRSV)) {
        if (logfailure) {
            (void)modperl_errsv(aTHX_ HTTP_INTERNAL_SERVER_ERROR,
                                NULL, NULL);
        }
        return FALSE;
    }
        
    return TRUE;
}

int modperl_require_file(pTHX_ const char *pv, int logfailure)
{
    require_pv(pv);

    if (SvTRUE(ERRSV)) {
        if (logfailure) {
            (void)modperl_errsv(aTHX_ HTTP_INTERNAL_SERVER_ERROR,
                                NULL, NULL);
        }
        return FALSE;
    }

    return TRUE;
}

static SV *modperl_hv_request_find(pTHX_ SV *in, char *classname, CV *cv)
{
    static char *r_keys[] = { "r", "_r", NULL };
    HV *hv = (HV *)SvRV(in);
    SV *sv = Nullsv;
    int i;

    for (i=0; r_keys[i]; i++) {
        int klen = i + 1; /* assumes r_keys[] will never change */
        SV **svp;

        if ((svp = hv_fetch(hv, r_keys[i], klen, FALSE)) && (sv = *svp)) {
            if (SvROK(sv) && (SvTYPE(SvRV(sv)) == SVt_PVHV)) {
                /* dig deeper */
                return modperl_hv_request_find(aTHX_ sv, classname, cv);
            }
            break;
        }
    }

    if (!sv) {
        Perl_croak(aTHX_
                   "method `%s' invoked by a `%s' object with no `r' key!",
                   cv ? GvNAME(CvGV(cv)) : "unknown",
                   HvNAME(SvSTASH(SvRV(in))));
    }

    return SvROK(sv) ? SvRV(sv) : sv;
}

MP_INLINE server_rec *modperl_sv2server_rec(pTHX_ SV *sv)
{
    return SvOBJECT(sv) ?
        (server_rec *)SvObjIV(sv) :
        modperl_global_get_server_rec();
}

MP_INLINE request_rec *modperl_sv2request_rec(pTHX_ SV *sv)
{
    return modperl_xs_sv2request_rec(aTHX_ sv, NULL, Nullcv);
}

request_rec *modperl_xs_sv2request_rec(pTHX_ SV *in, char *classname, CV *cv)
{
    SV *sv = Nullsv;
    MAGIC *mg;

    if (in == &PL_sv_undef) {
        return NULL;
    }

    if (SvROK(in)) {
        SV *rv = (SV*)SvRV(in);

        switch (SvTYPE(rv)) {
          case SVt_PVMG:
            sv = rv;
            break;
          case SVt_PVHV:
            sv = modperl_hv_request_find(aTHX_ in, classname, cv);
            break;
          default:
            Perl_croak(aTHX_ "panic: unsupported request_rec type %d",
                       SvTYPE(rv));
        }
    }

    if (!sv) {
        request_rec *r = NULL;
        (void)modperl_tls_get_request_rec(&r);

        if (!r) {
            if (classname && SvPOK(in) && !strEQ(classname, SvPVX(in))) {
                /* might be Apache::{Server,RequestRec}-> dual method */
                return NULL;
            }
            Perl_croak(aTHX_
                       "Apache->%s called without setting Apache->request!",
                       cv ? GvNAME(CvGV(cv)) : "unknown");
        }

        return r;
    }

    if ((mg = SvMAGIC(sv))) {
        return MgTypeExt(mg) ? (request_rec *)mg->mg_ptr : NULL;
    }
    else {
        if (classname && !sv_derived_from(in, classname)) {
            /* XXX: find something faster than sv_derived_from */
            return NULL;
        }
        return (request_rec *)SvIV(sv);
    }

    return NULL;
}

MP_INLINE SV *modperl_newSVsv_obj(pTHX_ SV *stashsv, SV *obj)
{
    SV *newobj;

    if (!obj) {
        obj = stashsv;
        stashsv = Nullsv;
    }

    newobj = newSVsv(obj);

    if (stashsv) {
        HV *stash = gv_stashsv(stashsv, TRUE);
        return sv_bless(newobj, stash);
    }

    return newobj;
}

MP_INLINE SV *modperl_ptr2obj(pTHX_ char *classname, void *ptr)
{
    SV *sv = newSV(0);

    MP_TRACE_h(MP_FUNC, "sv_setref_pv(%s, 0x%lx)\n",
               classname, (unsigned long)ptr);
    sv_setref_pv(sv, classname, ptr);

    return sv;
}

apr_pool_t *modperl_sv2pool(pTHX_ SV *obj)
{
    apr_pool_t *p = NULL;
    char *classname = NULL;
    IV ptr = 0;

    if ((SvROK(obj) && (SvTYPE(SvRV(obj)) == SVt_PVMG))) {
        ptr = SvObjIV(obj);
        classname = SvCLASS(obj);
    }
    else {
        STRLEN len;
        classname = SvPV(obj, len);
    }

    if (*classname != 'A') {
        /* XXX: could be a subclass */
        return NULL;
    }

    if (strnEQ(classname, "APR::", 5)) {
        classname += 5;
        switch (*classname) {
          case 'P':
            if (strEQ(classname, "Pool")) {
                p = (apr_pool_t *)ptr;
            }
            break;
          default:
            break;
        };
    }
    else if (strnEQ(classname, "Apache::", 8)) {
        classname += 8;
        switch (*classname) {
          case 'C':
            if (strEQ(classname, "Connection")) {
                p = ptr ? ((conn_rec *)ptr)->pool : NULL;
            }
            break;
          case 'R':
            if (strEQ(classname, "RequestRec")) {
                p = ptr ? ((request_rec *)ptr)->pool : NULL;
            }
            break;
          case 'S':
            if (strEQ(classname, "Server")) {
                p = ptr ? ((server_rec *)ptr)->process->pconf : NULL;
            }
            break;
          default:
            break;
        };
    }

    return p ? p : modperl_global_get_pconf();
}

char *modperl_apr_strerror(apr_status_t rv)
{
    dTHX;
    char buf[256];
    apr_strerror(rv, buf, sizeof(buf));
    return Perl_form(aTHX_ "%d:%s", rv, buf);
}

int modperl_errsv(pTHX_ int status, request_rec *r, server_rec *s)
{
    SV *sv = ERRSV;
    STRLEN n_a;

    if (SvTRUE(sv)) {
        if (SvMAGICAL(sv) && (SvCUR(sv) > 4) &&
            strnEQ(SvPVX(sv), " at ", 4))
        {
            /* Apache::exit was called */
            return DECLINED;
        }
#if 0
        if (modperl_sv_is_http_code(ERRSV, &status)) {
            return status;
        }
#endif
        if (r) {
            ap_log_rerror(APLOG_MARK, APLOG_ERR, 0, r, "%s", SvPV(sv, n_a));
        }
        else {
            ap_log_error(APLOG_MARK, APLOG_ERR, 0, s, "%s", SvPV(sv, n_a));
        }

        return status;
    }

    return status;
}

char *modperl_server_desc(server_rec *s, apr_pool_t *p)
{
    return apr_psprintf(p, "%s:%u", s->server_hostname, s->port);
}

#define dl_librefs "DynaLoader::dl_librefs"
#define dl_modules "DynaLoader::dl_modules"

void modperl_xs_dl_handles_clear(pTHXo)
{
    AV *librefs = get_av(dl_librefs, FALSE);
    if (librefs) {
        av_clear(librefs);
    }
}

apr_array_header_t *modperl_xs_dl_handles_get(pTHX_ apr_pool_t *p)
{
    I32 i;
    AV *librefs = get_av(dl_librefs, FALSE);
    AV *modules = get_av(dl_modules, FALSE);
    apr_array_header_t *handles;

    if (!librefs) {
	MP_TRACE_g(MP_FUNC,
                   "Could not get @%s for unloading.\n",
                   dl_librefs);
	return NULL;
    }

    if (!(AvFILL(librefs) >= 0)) {
        /* dl_librefs and dl_modules are empty */
        return NULL;
    }

    handles = apr_array_make(p, AvFILL(librefs)-1, sizeof(void *));

    for (i=0; i<=AvFILL(librefs); i++) {
	void *handle;
	SV *handle_sv = *av_fetch(librefs, i, FALSE);
	SV *module_sv = *av_fetch(modules, i, FALSE);

	if(!handle_sv) {
	    MP_TRACE_g(MP_FUNC,
                       "Could not fetch $%s[%d]!\n",
                       dl_librefs, (int)i);
	    continue;
	}
	handle = (void *)SvIV(handle_sv);

	MP_TRACE_g(MP_FUNC, "%s dl handle == 0x%lx\n",
                   SvPVX(module_sv), (unsigned long)handle);
	if (handle) {
	    *(void **)apr_array_push(handles) = handle;
	}
    }

    av_clear(modules);
    av_clear(librefs);

    return handles;
}

void modperl_xs_dl_handles_close(apr_pool_t *p, apr_array_header_t *handles)
{
    int i;

    if (!handles) {
	return;
    }

    for (i=0; i < handles->nelts; i++) {
        apr_dso_handle_t *dso = NULL;
        void *handle = ((void **)handles->elts)[i];

        MP_TRACE_g(MP_FUNC, "close 0x%lx\n", (unsigned long)handle);

        apr_os_dso_handle_put(&dso, (apr_os_dso_handle_t )handle, p);
        apr_dso_unload(dso);
    }
}

modperl_cleanup_data_t *modperl_cleanup_data_new(apr_pool_t *p, void *data)
{
    modperl_cleanup_data_t *cdata =
        (modperl_cleanup_data_t *)apr_pcalloc(p, sizeof(*cdata));
    cdata->pool = p;
    cdata->data = data;
    return cdata;
}

MP_INLINE modperl_uri_t *modperl_uri_new(apr_pool_t *p)
{
    modperl_uri_t *uri = (modperl_uri_t *)apr_pcalloc(p, sizeof(*uri));
    uri->pool = p;
    return uri;
}

MP_INLINE SV *modperl_hash_tie(pTHX_ 
                               const char *classname,
                               SV *tsv, void *p)
{
    SV *hv = (SV*)newHV();
    SV *rsv = sv_newmortal();

    sv_setref_pv(rsv, classname, p);
    sv_magic(hv, rsv, PERL_MAGIC_tied, Nullch, 0);

    return SvREFCNT_inc(sv_bless(sv_2mortal(newRV_noinc(hv)),
                                 gv_stashpv(classname, TRUE)));
}

MP_INLINE void *modperl_hash_tied_object(pTHX_ 
                                         const char *classname,
                                         SV *tsv)
{
    if (sv_derived_from(tsv, classname)) {
        if (SVt_PVHV == SvTYPE(SvRV(tsv))) {
            SV *hv = SvRV(tsv);
            MAGIC *mg;

            if (SvMAGICAL(hv)) {
                if ((mg = mg_find(hv, PERL_MAGIC_tied))) {
                    return (void *)MgObjIV(mg);
                }
                else {
                    Perl_warn(aTHX_ "Not a tied hash: (magic=%c)", mg);
                }
            }
            else {
                Perl_warn(aTHX_ "SV is not tied");
            }
        }
        else {
            return (void *)SvObjIV(tsv);
        }
    }
    else {
        Perl_croak(aTHX_
                   "argument is not a blessed reference "
                   "(expecting an %s derived object)", classname);
    }

    return NULL;
}

MP_INLINE void modperl_perl_av_push_elts_ref(pTHX_ AV *dst, AV *src)
{
    I32 i, j, src_fill = AvFILLp(src), dst_fill = AvFILLp(dst);

    av_extend(dst, src_fill);
    AvFILLp(dst) += src_fill+1;

    for (i=dst_fill+1, j=0; j<=AvFILLp(src); i++, j++) {
        AvARRAY(dst)[i] = SvREFCNT_inc(AvARRAY(src)[j]);
    }
}

/*
 * similar to hv_fetch_ent, but takes string key and key len rather than SV
 * also skips magic and utf8 fu, since we are only dealing with internal tables
 */
HE *modperl_perl_hv_fetch_he(pTHX_ HV *hv,
                             register char *key,
                             register I32 klen,
                             register U32 hash)
{
    register XPVHV *xhv;
    register HE *entry;

    xhv = (XPVHV *)SvANY(hv);
    if (!xhv->xhv_array) {
        return 0;
    }

    if (!hash) {
	PERL_HASH(hash, key, klen);
    }

    entry = ((HE**)xhv->xhv_array)[hash & (I32)xhv->xhv_max];

    for (; entry; entry = HeNEXT(entry)) {
        if (HeHASH(entry) != hash) {
            continue;
        }
        if (HeKLEN(entry) != klen) {
            continue;
        }
        if (HeKEY(entry) != key && memNE(HeKEY(entry), key, klen)) {
            continue;
        }
        return entry;
    }

    return 0;
}

/* XXX: same as Perl_do_sprintf(); 
 * but Perl_do_sprintf() is not part of the "public" api
 */
void modperl_perl_do_sprintf(pTHX_ SV *sv, I32 len, SV **sarg)
{
    STRLEN patlen;
    char *pat = SvPV(*sarg, patlen);
    bool do_taint = FALSE;

    sv_vsetpvfn(sv, pat, patlen, Null(va_list*), sarg + 1, len - 1, &do_taint);
    SvSETMAGIC(sv);
    if (do_taint) {
        SvTAINTED_on(sv);
    }
}

void modperl_perl_call_list(pTHX_ AV *subs, const char *name)
{
    I32 i, oldscope = PL_scopestack_ix;
    SV **ary = AvARRAY(subs);
    
    for (i=0; i<=AvFILLp(subs); i++) {
	CV *cv = (CV*)ary[i];
	SV *atsv = ERRSV;

	PUSHMARK(PL_stack_sp);
	call_sv((SV*)cv, G_EVAL|G_DISCARD);

	if (SvCUR(atsv)) {
            Perl_sv_catpvf(aTHX_ atsv, "%s failed--call queue aborted",
                           name);
	    while (PL_scopestack_ix > oldscope) {
		LEAVE;
            }
            Perl_croak(aTHX_ "%s", SvPVX(atsv));
	}
    }
}

void modperl_perl_exit(pTHX_ int status)
{
    ENTER;
    SAVESPTR(PL_diehook);
    PL_diehook = Nullsv; 
    Perl_croak(aTHX_ NULL);
}

MP_INLINE SV *modperl_dir_config(pTHX_ request_rec *r, server_rec *s,
                                 char *key, SV *sv_val)
{
    SV *retval = &PL_sv_undef;

    if (r && r->per_dir_config) {				   
        MP_dDCFG;
        retval = modperl_table_get_set(aTHX_ dcfg->SetVar,
                                       key, sv_val, FALSE);
    }

    if (!SvTRUE(retval)) {
        if (s && s->module_config) {
            MP_dSCFG(s);
            SvREFCNT_dec(retval); /* in case above did newSV(0) */
            retval = modperl_table_get_set(aTHX_ scfg->SetVar,
                                           key, sv_val, FALSE);
        }
        else {
            retval = &PL_sv_undef;
        }
    }
        
    return retval;
}

SV *modperl_table_get_set(pTHX_ apr_table_t *table, char *key,
                          SV *sv_val, int do_taint)
{
    SV *retval = &PL_sv_undef;

    if (table == NULL) { 
        /* do nothing */
    }
    else if (key == NULL) { 
        retval = modperl_hash_tie(aTHX_ "APR::Table",
                                  Nullsv, (void*)table); 
    }
    else if (sv_val == &PL_sv_no) { /* no val was passed */
        char *val; 
        if ((val = (char *)apr_table_get(table, key))) { 
            retval = newSVpv(val, 0); 
        } 
        else { 
            retval = newSV(0); 
        } 
        if (do_taint) { 
            SvTAINTED_on(retval); 
        } 
    }
    else if (sv_val == &PL_sv_undef) { /* val was passed in as undef */
        apr_table_unset(table, key); 
    }
    else { 
        apr_table_set(table, key, SvPV_nolen(sv_val));
    } 

    return retval;
}

MP_INLINE int modperl_perl_module_loaded(pTHX_ const char *name)
{
    return gv_stashpv(name, FALSE) ? 1 : 0;
}

/* same as Symbol::gensym() */
SV *modperl_perl_gensym(pTHX_ char *pack)
{
    GV *gv = newGVgen(pack);
    SV *rv = newRV((SV*)gv);
    (void)hv_delete(gv_stashpv(pack, TRUE), 
                    GvNAME(gv), GvNAMELEN(gv), G_DISCARD);
    return rv;
}
