#ifndef MODPERL_PERL_H
#define MODPERL_PERL_H

typedef struct {
    I32 pid;
    Uid_t uid, euid;
    Gid_t gid, egid;
} modperl_perl_ids_t;

void modperl_perl_ids_get(modperl_perl_ids_t *ids);

void modperl_perl_init_ids(pTHX_ modperl_perl_ids_t *ids);

apr_status_t modperl_perl_init_ids_mip(pTHX_ modperl_interp_pool_t *mip,
                                       void *data);

#endif /* MODPERL_PERL_H */
