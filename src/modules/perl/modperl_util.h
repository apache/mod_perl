#ifndef MODPERL_UTIL_H
#define MODPERL_UTIL_H

#ifdef MP_DEBUG
#define MP_INLINE
#else
#define MP_INLINE APR_INLINE
#endif

#ifdef WIN32
#   define MP_FUNC_T(name) (_stdcall *name)
/* XXX: not all functions get inlined
 * so its unclear what to and not to include in the .def files
 */
#   undef MP_INLINE
#   define MP_INLINE
#else
#   define MP_FUNC_T(name)          (*name)
#endif

#define MP_SSTRLEN(string) (sizeof(string)-1)

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

#define MP_SvGROW(sv, len) \
    (void)SvUPGRADE(sv, SVt_PV); \
    SvGROW(sv, len+1)

#define MP_SvCUR_set(sv, len) \
    SvCUR_set(sv, len); \
    *SvEND(sv) = '\0'; \
    SvPOK_only(sv)

#define MP_magical_untie(sv, mg_flags) \
    mg_flags = SvMAGICAL((SV*)sv); \
    SvMAGICAL_off((SV*)sv)

#define MP_magical_tie(sv, mg_flags) \
    SvFLAGS((SV*)sv) |= mg_flags

#define MP_FAILURE_CROAK(rc_run) do { \
        apr_status_t rc = rc_run; \
        if (rc != APR_SUCCESS) { \
            Perl_croak(aTHX_ modperl_apr_strerror(rc)); \
        } \
    } while (0)

/* check whether the response phase has been initialized already */
#define MP_CHECK_WBUCKET_INIT(func) \
    if (!rcfg->wbucket) { \
        Perl_croak(aTHX_ func " can't be called before the response phase"); \
    }

/* turn off cgi header parsing. in case we are already inside
 *     modperl_callback_per_dir(MP_RESPONSE_HANDLER, r); 
 * but haven't sent any data yet, it's too late to change
 * MpReqPARSE_HEADERS, so change the wbucket's private flag directly
 */
#define MP_CGI_HEADER_PARSER_OFF(rcfg) \
    MpReqPARSE_HEADERS_Off(rcfg); \
    if (rcfg->wbucket) { \
        rcfg->wbucket->header_parse = 0; \
    } 

MP_INLINE server_rec *modperl_sv2server_rec(pTHX_ SV *sv);
MP_INLINE request_rec *modperl_sv2request_rec(pTHX_ SV *sv);

request_rec *modperl_xs_sv2request_rec(pTHX_ SV *sv, char *classname, CV *cv);

MP_INLINE SV *modperl_newSVsv_obj(pTHX_ SV *stashsv, SV *obj);

MP_INLINE SV *modperl_ptr2obj(pTHX_ char *classname, void *ptr);

MP_INLINE SV *modperl_perl_sv_setref_uv(pTHX_ SV *rv,
                                        const char *classname, UV uv);

apr_pool_t *modperl_sv2pool(pTHX_ SV *obj);

char *modperl_apr_strerror(apr_status_t rv);

int modperl_errsv(pTHX_ int status, request_rec *r, server_rec *s);

int modperl_require_module(pTHX_ const char *pv, int logfailure);
int modperl_require_file(pTHX_ const char *pv, int logfailure);

char *modperl_server_desc(server_rec *s, apr_pool_t *p);

void modperl_xs_dl_handles_clear(pTHX);

void **modperl_xs_dl_handles_get(pTHX);

void modperl_xs_dl_handles_close(void **handles);

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

void modperl_str_toupper(char *str);

void modperl_perl_do_sprintf(pTHX_ SV *sv, I32 len, SV **sarg);

void modperl_perl_call_list(pTHX_ AV *subs, const char *name);

void modperl_perl_exit(pTHX_ int status);

MP_INLINE SV *modperl_dir_config(pTHX_ request_rec *r, server_rec *s,
                                 char *key, SV *sv_val);
    
SV *modperl_table_get_set(pTHX_ apr_table_t *table, char *key,
                          SV *sv_val, int do_taint);

MP_INLINE int modperl_perl_module_loaded(pTHX_ const char *name);

SV *modperl_perl_gensym(pTHX_ char *pack);

void modperl_clear_symtab(pTHX_ HV *symtab);

#endif /* MODPERL_UTIL_H */
