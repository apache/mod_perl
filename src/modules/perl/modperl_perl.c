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

void modperl_perl_core_global_init(pTHX)
{
    modperl_perl_core_global_t *cglobals = MP_perl_core_global_entries;

    while (cglobals->name) {
        GV *gv = gv_fetchpv(cglobals->core_name, TRUE, SVt_PVCV);
        GvCV(gv) = get_cv(cglobals->sub_name, TRUE);
        GvIMPORTED_CV_on(gv);
        cglobals++;
    }
}

static void modperl_perl_ids_get(modperl_perl_ids_t *ids)
{
    ids->pid  = (I32)getpid();
#ifndef WIN32
    ids->uid  = getuid();
    ids->euid = geteuid(); 
    ids->gid  = getgid(); 
    ids->gid  = getegid(); 

    MP_TRACE_g(MP_FUNC, 
               "uid=%d, euid=%d, gid=%d, egid=%d\n",
               (int)ids->uid, (int)ids->euid,
               (int)ids->gid, (int)ids->egid);
#endif
}

static void modperl_perl_init_ids(pTHX_ modperl_perl_ids_t *ids)
{
    sv_setiv(GvSV(gv_fetchpv("$", TRUE, SVt_PV)), ids->pid);

#ifndef WIN32
    PL_uid  = ids->uid;
    PL_euid = ids->euid;
    PL_gid  = ids->gid;
    PL_egid = ids->egid;
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

    if (PL_endav) {
        modperl_perl_call_list(aTHX_ PL_endav, "END");
    }

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

/*
 * modperl_svptr_table api is an add-on to the Perl ptr_table_ api.
 * we use a PTR_TBL_t to map config structures (e.g. from parsed
 * httpd.conf or .htaccess), where each interpreter needs to have its
 * own copy of the Perl SV object.  we do not use an HV* for this, because
 * the HV keys must be SVs with a string value, too much overhead.
 * we do not use an apr_hash_t because they only have the lifetime of
 * the pool used to create them. which may or may not be the same lifetime
 * of the objects we need to lookup.
 */

#ifdef USE_ITHREADS

#ifdef MP_PERL_5_6_x
#   define my_sv_dup(s, p) sv_dup(s)

typedef struct {
    AV *stashes;
    UV flags;
    PerlInterpreter *proto_perl;
} CLONE_PARAMS;

#else
#   define my_sv_dup(s, p) sv_dup(s, p)
#endif

/*
 * copy a PTR_TBL_t whos PTR_TBL_ENT_t values are SVs.
 * the SVs are dup-ed so each interpreter has its own copy.
 */
PTR_TBL_t *modperl_svptr_table_clone(pTHX_ PerlInterpreter *proto_perl,
                                     PTR_TBL_t *source)
{
    UV i;
    PTR_TBL_t *tbl;
    PTR_TBL_ENT_t **src_ary, **dst_ary;
    CLONE_PARAMS parms;

    Newz(0, tbl, 1, PTR_TBL_t);
    tbl->tbl_max	= source->tbl_max;
    tbl->tbl_items	= source->tbl_items;
    Newz(0, tbl->tbl_ary, tbl->tbl_max + 1, PTR_TBL_ENT_t *);

    dst_ary = tbl->tbl_ary;
    src_ary = source->tbl_ary;

    Zero(&parms, 0, CLONE_PARAMS);
    parms.flags = 0;
    parms.stashes = newAV();

    for (i=0; i < source->tbl_max; i++, dst_ary++, src_ary++) {
	PTR_TBL_ENT_t *src_ent, *dst_ent=NULL;

	if (!*src_ary) {
	    continue;
        }

	for (src_ent = *src_ary;
             src_ent;
             src_ent = src_ent->next)
        {
            if (dst_ent == NULL) {
                Newz(0, dst_ent, 1, PTR_TBL_ENT_t);
                *dst_ary = dst_ent;
            }
            else {
                Newz(0, dst_ent->next, 1, PTR_TBL_ENT_t);
                dst_ent = dst_ent->next;
            }

            /* key is just a pointer we do not modify, no need to copy */
            dst_ent->oldval = src_ent->oldval;

            dst_ent->newval =
                SvREFCNT_inc(my_sv_dup((SV*)src_ent->newval, &parms));
        }
    }

    SvREFCNT_dec(parms.stashes);

    return tbl;
}

#endif

/*
 * need to free the SV values in addition to ptr_table_free
 */
void modperl_svptr_table_destroy(pTHX_ PTR_TBL_t *tbl)
{
    UV i;
    PTR_TBL_ENT_t **ary = tbl->tbl_ary;

    for (i=0; i < tbl->tbl_max; i++, ary++) {
	PTR_TBL_ENT_t *ent;

	if (!*ary) {
	    continue;
        }

	for (ent = *ary; ent; ent = ent->next) {
            if (!ent->newval) {
                continue;
            }

            SvREFCNT_dec((SV*)ent->newval);
            ent->newval = NULL;
        }
    }

    ptr_table_free(tbl);
}

/*
 * the Perl ptr_table_ api does not provide a function to remove
 * an entry from the table.  we need to SvREFCNT_dec the SV value
 * anyhow.
 */
void modperl_svptr_table_delete(pTHX_ PTR_TBL_t *tbl, void *key)
{
    PTR_TBL_ENT_t *entry, **oentry;
    UV hash = PTR2UV(key);

    oentry = &tbl->tbl_ary[hash & tbl->tbl_max];
    entry = *oentry;

    for (; entry; oentry = &entry->next, entry = *oentry) {
	if (entry->oldval == key) {
            *oentry = entry->next;
            SvREFCNT_dec((SV*)entry->newval);
            Safefree(entry);
            tbl->tbl_items--;
	    return;
	}
    }
}
