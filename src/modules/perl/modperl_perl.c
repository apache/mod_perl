/* Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "mod_perl.h"

/* this module contains mod_perl small tweaks to the Perl runtime
 * others (larger tweaks) are in their own modules, e.g. modperl_env.c
 */

typedef struct {
    const char *name;
    const char *sub_name;
    const char *core_name;
} modperl_perl_core_global_t;

#define MP_PERL_CORE_GLOBAL_ENT(name) \
{ name, "ModPerl::Util::" name, "CORE::GLOBAL::" name }

static modperl_perl_core_global_t MP_perl_core_global_entries[] = {
    MP_PERL_CORE_GLOBAL_ENT("exit"),
    { NULL },
};

XS(XS_ModPerl__Util_exit); /* prototype to pass -Wmissing-prototypes */
XS(XS_ModPerl__Util_exit)
{
    dXSARGS;
    int status;
    if (items < 0 || items > 1) {
        Perl_croak(aTHX_ "Usage: ModPerl::Util::exit(status=0)");
    }
    /* default: 0 */
    status = items < 1 ? 0 : (int)SvIV(ST(0));
    modperl_perl_exit(aTHX_ status);

    XSRETURN_EMPTY;
}

void modperl_perl_core_global_init(pTHX)
{
    modperl_perl_core_global_t *cglobals = MP_perl_core_global_entries;

    while (cglobals->name) {
        GV *gv = gv_fetchpv(cglobals->core_name, TRUE, SVt_PVCV);
#ifdef MUTABLE_CV
        GvCV_set(gv,
                 MUTABLE_CV(SvREFCNT_inc(get_cv(cglobals->sub_name, TRUE))));
#else
        GvCV_set(gv,
                 (CV*)(SvREFCNT_inc(get_cv(cglobals->sub_name, TRUE))));
#endif
        GvIMPORTED_CV_on(gv);
        cglobals++;
    }

    newXS("ModPerl::Util::exit", XS_ModPerl__Util_exit, __FILE__);
}

static void modperl_perl_ids_get(modperl_perl_ids_t *ids)
{
    ids->pid  = (I32)getpid();
#ifdef MP_MAINTAIN_PPID
    ids->ppid = (I32)getppid();
#endif
#ifndef WIN32
    ids->uid  = getuid();
    ids->euid = geteuid();
    ids->gid  = getgid();
    ids->egid  = getegid();

    MP_TRACE_r(MP_FUNC,
               "pid=%d, "
#ifdef MP_MAINTAIN_PPID
               "ppid=%d, "
#endif
               "uid=%" Uid_t_f ", euid=%" Uid_t_f ", "
               "gid=%" Gid_t_f ", egid=%" Gid_t_f,
               (int)ids->pid,
#ifdef MP_MAINTAIN_PPID
               (int)ids->ppid,
#endif
               ids->uid, ids->euid,
               ids->gid, ids->egid);
#endif /* #ifndef WIN32 */
}

static void modperl_perl_init_ids(pTHX_ modperl_perl_ids_t *ids)
{
    sv_setiv(GvSV(gv_fetchpv("$", TRUE, SVt_PV)), ids->pid);

#if !MP_PERL_VERSION_AT_LEAST(5, 16, 0)
#ifndef WIN32
    PL_uid  = ids->uid;
    PL_euid = ids->euid;
    PL_gid  = ids->gid;
    PL_egid = ids->egid;
#endif
#ifdef MP_MAINTAIN_PPID
    PL_ppid = ids->ppid;
#endif
#endif
}


#ifdef USE_ITHREADS

static apr_status_t modperl_perl_init_ids_mip(pTHX_ modperl_interp_pool_t *mip,
                                              void *data)
{
    modperl_perl_init_ids(aTHX_ (modperl_perl_ids_t *)data);
    return APR_SUCCESS;
}

#endif /* USE_ITHREADS */

void modperl_perl_init_ids_server(server_rec *s)
{
    modperl_perl_ids_t ids;
    modperl_perl_ids_get(&ids);
#ifdef USE_ITHREADS
    modperl_interp_mip_walk_servers(NULL, s,
                                    modperl_perl_init_ids_mip,
                                    (void*)&ids);
#else
    modperl_perl_init_ids(aTHX_ &ids);
#endif
}

void modperl_perl_destruct(PerlInterpreter *perl)
{
    char **orig_environ = NULL;
    PTR_TBL_t *module_commands;
    dTHXa(perl);

    PERL_SET_CONTEXT(perl);

    modperl_perl_call_endav(aTHX);

    PL_perl_destruct_level = modperl_perl_destruct_level();

#ifdef USE_ENVIRON_ARRAY
    /* XXX: otherwise Perl may try to free() environ multiple times
     * but it wasn't Perl that modified environ
     * at least, not if modperl is doing things right
     * this is a bug in Perl.
     */
#   ifdef WIN32
    /*
     * PL_origenviron = environ; doesn't work under win32 service.
     * we pull a different stunt here that has the same effect of
     * tricking perl into _not_ freeing the real 'environ' array.
     * instead temporarily swap with a dummy array we malloc
     * here which is ok to let perl free.
     */
    orig_environ = environ;
    environ = safemalloc(2 * sizeof(char *));
    environ[0] = NULL;
#   else
    PL_origenviron = environ;
#   endif
#endif

    {
        dTHXa(perl);

        if ((module_commands = modperl_module_config_table_get(aTHX_ FALSE))) {
            modperl_svptr_table_destroy(aTHX_ module_commands);
        }
    }

    perl_destruct(perl);

    /* XXX: big bug in 5.6.1 fixed in 5.7.2+
     * XXX: try to find a workaround for 5.6.1
     */
#if defined(WIN32) && !defined(CLONEf_CLONE_HOST)
#   define MP_NO_PERL_FREE
#endif

#ifndef MP_NO_PERL_FREE
    perl_free(perl);
#endif

#ifdef USE_ENVIRON_ARRAY
    if (orig_environ) {
        environ = orig_environ;
    }
#endif
}

void modperl_perl_call_endav(pTHX)
{
     if (PL_endav) {
         modperl_perl_call_list(aTHX_ PL_endav, "END");
     }
}

#if !(MP_PERL_VERSION_AT_MOST(5, 8, 0)) && \
    (defined(USE_HASH_SEED) || defined(USE_HASH_SEED_EXPLICIT))
#define MP_NEED_HASH_SEED_FIXUP
#endif

#ifdef MP_NEED_HASH_SEED_FIXUP
static UV   MP_init_hash_seed = 0;
static bool MP_init_hash_seed_set = FALSE;
#endif

/* see modperl_hash_seed_set() */
void modperl_hash_seed_init(apr_pool_t *p)
{
#ifdef MP_NEED_HASH_SEED_FIXUP
    char *s;
    /* check if there is a specific hash seed passed via the env var
     * and if that's the case -- use it */
    apr_status_t rv = apr_env_get(&s, "PERL_HASH_SEED", p);
    if (rv == APR_SUCCESS) {
        if (s) {
            while (isSPACE(*s)) s++;
        }
        if (s && isDIGIT(*s)) {
            MP_init_hash_seed = (UV)Atol(s); /* XXX: Atoul()? */
            MP_init_hash_seed_set = TRUE;
        }
    }

    /* calculate our own random hash seed */
    if (!MP_init_hash_seed_set) {
        apr_uuid_t *uuid = (apr_uuid_t *)apr_palloc(p, sizeof(apr_uuid_t));
        char buf[APR_UUID_FORMATTED_LENGTH + 1];
        int i;

        apr_initialize();
        apr_uuid_get(uuid);
        apr_uuid_format(buf, uuid);
        /* fprintf(stderr, "UUID: %s\n", buf); */

        /* XXX: need a better alg to convert uuid string into a seed */
        for (i=0; buf[i]; i++){
            MP_init_hash_seed += (UV)(i+1)*(buf[i]+MP_init_hash_seed);
        }

        MP_init_hash_seed_set = TRUE;
    }
#endif
}

/* before 5.8.1, perl was using HASH_SEED=0, starting from 5.8.1
 * it randomizes if perl was compiled with ccflags -DUSE_HASH_SEED
 * or -DUSE_HASH_SEED_EXPLICIT, in which case we need to tell perl
 * to use the same seed everywhere */
void modperl_hash_seed_set(pTHX)
{
#ifdef MP_NEED_HASH_SEED_FIXUP
    if (MP_init_hash_seed_set) {
#if MP_PERL_VERSION_AT_LEAST(5, 17, 6)
        memcpy(&PL_hash_seed, &MP_init_hash_seed,
                sizeof(PL_hash_seed) > sizeof(MP_init_hash_seed) ?
                    sizeof(MP_init_hash_seed) : sizeof(PL_hash_seed));
        PL_hash_seed_set   = MP_init_hash_seed_set;
#elif MP_PERL_VERSION_AT_LEAST(5, 8, 2)
        PL_rehash_seed     = MP_init_hash_seed;
        PL_rehash_seed_set = MP_init_hash_seed_set;
#else
        PL_hash_seed       = MP_init_hash_seed;
        PL_hash_seed_set   = MP_init_hash_seed_set;
#endif
    }
#endif
}
