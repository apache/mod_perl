#ifndef MODPERL_PERL_H
#define MODPERL_PERL_H

typedef struct {
    I32 pid;
    Uid_t uid, euid;
    Gid_t gid, egid;
} modperl_perl_ids_t;

void modperl_perl_core_global_init(pTHX);

void modperl_perl_init_ids_server(server_rec *s);

void modperl_perl_destruct(PerlInterpreter *perl);

#ifdef USE_ITHREADS

PTR_TBL_t *modperl_svptr_table_clone(pTHX_ PerlInterpreter *proto_perl,
                                     PTR_TBL_t *source);

void modperl_svptr_table_destroy(pTHX_ PTR_TBL_t *tbl);

#endif

void modperl_svptr_table_delete(pTHX_ PTR_TBL_t *tbl, void *key);

#endif /* MODPERL_PERL_H */
