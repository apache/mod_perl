#ifndef MODPERL_MGV_H
#define MODPERL_MGV_H

modperl_mgv_t *modperl_mgv_new(apr_pool_t *p);

int modperl_mgv_equal(modperl_mgv_t *mgv1,
                      modperl_mgv_t *mgv2);

modperl_mgv_t *modperl_mgv_compile(pTHX_ apr_pool_t *p, const char *name);

char *modperl_mgv_name_from_sv(pTHX_ apr_pool_t *p, SV *sv);

GV *modperl_mgv_lookup(pTHX_ modperl_mgv_t *symbol);

GV *modperl_mgv_lookup_autoload(pTHX_ modperl_mgv_t *symbol,
                                server_rec *s, apr_pool_t *p);

int modperl_mgv_resolve(pTHX_ modperl_handler_t *handler,
                        apr_pool_t *p, const char *name);

void modperl_mgv_append(pTHX_ apr_pool_t *p, modperl_mgv_t *symbol,
                        const char *name);

char *modperl_mgv_as_string(pTHX_ modperl_mgv_t *symbol,
                            apr_pool_t *p, int package);

#ifdef USE_ITHREADS
int modperl_mgv_require_module(pTHX_ modperl_mgv_t *symbol,
                               server_rec *s, apr_pool_t *p);
#endif

void modperl_mgv_hash_handlers(apr_pool_t *p, server_rec *s);

#define modperl_mgv_sv(sv) \
(isGV(sv) ? GvSV(sv) : (SV*)sv)

#define modperl_mgv_cv(sv) \
GvCV(sv)

#endif /* MODPERL_MGV_H */
