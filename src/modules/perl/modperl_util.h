#ifndef MODPERL_UTIL_H
#define MODPERL_UTIL_H

#ifdef MP_DEBUG
#define MP_INLINE
#else
#define MP_INLINE APR_INLINE
#endif

#ifdef WIN32
#   define MP_FUNC_T(name) (_stdcall *name)
#else
#   define MP_FUNC_T(name)          (*name)
#endif

#ifndef strcaseEQ
#   define strcaseEQ(s1,s2) (!strcasecmp(s1,s2))
#endif
#ifndef strncaseEQ
#   define strncaseEQ(s1,s2,l) (!strncasecmp(s1,s2,l))
#endif

#ifndef SvCLASS
#define SvCLASS(o) HvNAME(SvSTASH(SvRV(o)))
#endif

#define SvObjIV(o) SvIV((SV*)SvRV(o))
#define MgObjIV(m) SvIV((SV*)SvRV(m->mg_obj))

#define MP_magical_untie(sv, mg_flags) \
    mg_flags = SvMAGICAL((SV*)sv); \
    SvMAGICAL_off((SV*)sv)

#define MP_magical_tie(sv, mg_flags) \
    SvFLAGS((SV*)sv) |= mg_flags

MP_INLINE server_rec *modperl_sv2server_rec(pTHX_ SV *sv);
MP_INLINE request_rec *modperl_sv2request_rec(pTHX_ SV *sv);

request_rec *modperl_xs_sv2request_rec(pTHX_ SV *sv, char *classname, CV *cv);

MP_INLINE SV *modperl_newSVsv_obj(pTHX_ SV *stashsv, SV *obj);

MP_INLINE SV *modperl_ptr2obj(pTHX_ char *classname, void *ptr);

apr_pool_t *modperl_sv2pool(pTHX_ SV *obj);

char *modperl_apr_strerror(apr_status_t rv);

int modperl_errsv(pTHX_ int status, request_rec *r, server_rec *s);

int modperl_require_module(pTHX_ const char *pv, int logfailure);
int modperl_require_file(pTHX_ const char *pv, int logfailure);

char *modperl_server_desc(server_rec *s, apr_pool_t *p);

void modperl_xs_dl_handles_clear(pTHXo);

apr_array_header_t *modperl_xs_dl_handles_get(pTHX_ apr_pool_t *p);

void modperl_xs_dl_handles_close(apr_pool_t *p, apr_array_header_t *handles);

modperl_cleanup_data_t *modperl_cleanup_data_new(apr_pool_t *p, void *data);

MP_INLINE modperl_uri_t *modperl_uri_new(apr_pool_t *p);

/* tie %hash */
MP_INLINE SV *modperl_hash_tie(pTHX_ const char *classname,
                               SV *tsv, void *p);

/* tied %hash */
MP_INLINE void *modperl_hash_tied_object(pTHX_ const char *classname,
                                         SV *tsv);

MP_INLINE void modperl_perl_av_push_elts_ref(pTHX_ AV *dst, AV *src);

HE *modperl_perl_hv_fetch_he(pTHX_ HV *hv,
                             register char *key,
                             register I32 klen,
                             register U32 hash);

#define hv_fetch_he(hv,k,l,h) \
    modperl_perl_hv_fetch_he(aTHX_ hv, k, l, h)

void modperl_perl_call_list(pTHX_ AV *subs, const char *name);

void modperl_perl_exit(pTHX_ int status);

MP_INLINE SV *modperl_dir_config(pTHX_ request_rec *r, server_rec *s,
                                 char *key, SV *sv_val);
    
SV *modperl_table_get_set(pTHX_ apr_table_t *table, char *key,
                          SV *sv_val, int do_taint);

MP_INLINE int modperl_perl_module_loaded(pTHX_ const char *name);

#endif /* MODPERL_UTIL_H */
