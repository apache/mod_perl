#ifndef MODPERL_MGV_H
#define MODPERL_MGV_H

modperl_mgv_t *modperl_mgv_new(apr_pool_t *p);

modperl_mgv_t *modperl_mgv_compile(pTHX_ apr_pool_t *p, const char *name);

GV *modperl_mgv_lookup(pTHX_ modperl_mgv_t *symbol);

int modperl_mgv_resolve(pTHX_ modperl_handler_t *handler,
                        apr_pool_t *p, const char *name);

void modperl_mgv_append(pTHX_ apr_pool_t *p, modperl_mgv_t *symbol,
                        const char *name);

char *modperl_mgv_as_string(pTHX_ modperl_mgv_t *symbol,
                            apr_pool_t *p);

void modperl_mgv_hash_handlers(apr_pool_t *p, server_rec *s);

#define modperl_mgv_sv(sv) \
(isGV(sv) ? GvSV(sv) : (SV*)sv)

#define modperl_mgv_cv(sv) \
GvCV(sv)

#endif /* MODPERL_MGV_H */
