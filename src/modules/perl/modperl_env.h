#ifndef MODPERL_ENV_H
#define MODPERL_ENV_H

#ifndef ENVHV
#   define ENVHV GvHV(PL_envgv)
#endif

#define modperl_env_untie(mg_flags) \
    MP_magical_untie(ENVHV, mg_flags)

#define modperl_env_tie(mg_flags) \
    MP_magical_tie(ENVHV, mg_flags)

void modperl_env_hash_keys(void);

void modperl_env_clear(pTHX);

void modperl_env_default_populate(pTHX);

void modperl_env_request_populate(pTHX_ request_rec *r);

void modperl_env_request_tie(pTHX_ request_rec *r);

void modperl_env_request_untie(pTHX_ request_rec *r);

void modperl_env_init(void);

#endif /* MODPERL_ENV_H */
