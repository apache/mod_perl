#ifndef MODPERL_PERL_H
#define MODPERL_PERL_H

/* starting from 5.8.1 perl caches ppids, so we need to main our
 * own. some distros fetch fake 5.8.0 with changes from 5.8.1, so we
 * need to do that for those fake 5.8.0 as well. real 5.8.0 doesn't
 * have THREADS_HAVE_PIDS defined.
 */
#if PERL_REVISION == 5 && PERL_VERSION >= 8 && THREADS_HAVE_PIDS
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

void modperl_hash_seed_init(apr_pool_t *p);

void modperl_hash_seed_set(pTHX);

#endif /* MODPERL_PERL_H */
