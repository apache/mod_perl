#ifndef MODPERL_ENV_H
#define MODPERL_ENV_H

#ifndef ENVHV
#   define ENVHV GvHV(PL_envgv)
#endif

#define modperl_env_untie(mg_flags) \
    MP_magical_untie(ENVHV, mg_flags)

#define modperl_env_tie(mg_flags) \
    MP_magical_tie(ENVHV, mg_flags)

#define modperl_envelem_tie(sv, key, klen) \
    sv_magic(sv, Nullsv, 'e', key, klen)

void modperl_env_hash_keys(void);

void modperl_env_clear(pTHX);

void modperl_env_configure_server(pTHX_ apr_pool_t *p, server_rec *s);

void modperl_env_configure_request(request_rec *r);

void modperl_env_default_populate(pTHX);

void modperl_env_request_populate(pTHX_ request_rec *r);

void modperl_env_request_tie(pTHX_ request_rec *r);

void modperl_env_request_untie(pTHX_ request_rec *r);

void modperl_env_init(void);

void modperl_env_unload(void);

#endif /* MODPERL_ENV_H */
