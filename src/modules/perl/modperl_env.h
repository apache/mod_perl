#ifndef MODPERL_ENV_H
#define MODPERL_ENV_H

#define modperl_env_untie(mg_flags) \
    mg_flags = SvMAGICAL((SV*)GvHV(PL_envgv)); \
    SvMAGICAL_off((SV*)GvHV(PL_envgv))

#define modperl_env_tie(mg_flags) \
    SvFLAGS((SV*)GvHV(PL_envgv)) |= mg_flags

void modperl_env_request_populate(pTHX_ request_rec *r);

void modperl_env_request_tie(pTHX_ request_rec *r);

void modperl_env_request_untie(pTHX_ request_rec *r);

#endif /* MODPERL_ENV_H */
