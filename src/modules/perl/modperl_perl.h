#ifndef MODPERL_PERL_H
#define MODPERL_PERL_H

#if PERL_REVISION == 5 && \
    (PERL_VERSION == 8 && PERL_SUBVERSION >= 1 || PERL_VERSION >= 9) && \
    THREADS_HAVE_PIDS
#define MP_MAINTAIN_PPID
#endif

typedef struct {
    I32 pid;
    Uid_t uid, euid;
    Gid_t gid, egid;
#ifdef MP_MAINTAIN_PPID
    Uid_t ppid;
#endif
} modperl_perl_ids_t;

void modperl_perl_core_global_init(pTHX);

void modperl_perl_init_ids_server(server_rec *s);

void modperl_perl_destruct(PerlInterpreter *perl);

#endif /* MODPERL_PERL_H */
