#ifndef MODPERL_PERL_H
#define MODPERL_PERL_H

typedef struct {
    I32 pid;
    Uid_t uid, euid;
    Gid_t gid, egid;
} modperl_perl_ids_t;

void modperl_perl_core_global_init(pTHX);

void modperl_perl_init_ids_server(server_rec *s);

#endif /* MODPERL_PERL_H */
