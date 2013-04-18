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

#if MP_PERL_BRANCH(5, 6)
#   define my_sv_dup(s, p) SvREFCNT_inc(sv_dup(s))

typedef struct {
    AV *stashes;
    UV flags;
    PerlInterpreter *proto_perl;
} CLONE_PARAMS;

#else
#   ifdef sv_dup_inc
#       define my_sv_dup(s, p) sv_dup_inc(s, p)
#   else
#       define my_sv_dup(s, p) SvREFCNT_inc(sv_dup(s, p))
#   endif
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

    Newxz(tbl, 1, PTR_TBL_t);
    tbl->tbl_max        = source->tbl_max;
    tbl->tbl_items        = source->tbl_items;
    Newxz(tbl->tbl_ary, tbl->tbl_max + 1, PTR_TBL_ENT_t *);

    dst_ary = tbl->tbl_ary;
    src_ary = source->tbl_ary;

    Zero(&parms, 1, CLONE_PARAMS);
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
                Newxz(dst_ent, 1, PTR_TBL_ENT_t);
                *dst_ary = dst_ent;
            }
            else {
                Newxz(dst_ent->next, 1, PTR_TBL_ENT_t);
                dst_ent = dst_ent->next;
            }

            /* key is just a pointer we do not modify, no need to copy */
            dst_ent->oldval = src_ent->oldval;

            dst_ent->newval = my_sv_dup((SV*)src_ent->newval, &parms);
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

    modperl_svptr_table_free(aTHX_ tbl);
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

/*
 * XXX: the following are a copy of the Perl 5.8.0 Perl_ptr_table api
 * renamed s/Perl_ptr/modperl_svptr/g;
 * two reasons:
 *   these functions do not exist without -DUSE_ITHREADS
 *   the clear/free functions do not exist in 5.6.x
 */

/* create a new pointer-mapping table */

PTR_TBL_t *
modperl_svptr_table_new(pTHX)
{
    PTR_TBL_t *tbl;
    Newxz(tbl, 1, PTR_TBL_t);
    tbl->tbl_max        = 511;
    tbl->tbl_items        = 0;
    Newxz(tbl->tbl_ary, tbl->tbl_max + 1, PTR_TBL_ENT_t*);
    return tbl;
}

/* map an existing pointer using a table */

void *
modperl_svptr_table_fetch(pTHX_ PTR_TBL_t *tbl, void *sv)
{
    PTR_TBL_ENT_t *tblent;
    UV hash = PTR2UV(sv);
    assert(tbl);
    tblent = tbl->tbl_ary[hash & tbl->tbl_max];
    for (; tblent; tblent = tblent->next) {
        if (tblent->oldval == sv)
            return tblent->newval;
    }
    return (void*)NULL;
}

/* add a new entry to a pointer-mapping table */

void
modperl_svptr_table_store(pTHX_ PTR_TBL_t *tbl, void *oldv, void *newv)
{
    PTR_TBL_ENT_t *tblent, **otblent;
    /* XXX this may be pessimal on platforms where pointers aren't good
     * hash values e.g. if they grow faster in the most significant
     * bits */
    UV hash = PTR2UV(oldv);
    bool i = 1;

    assert(tbl);
    otblent = &tbl->tbl_ary[hash & tbl->tbl_max];
    for (tblent = *otblent; tblent; i=0, tblent = tblent->next) {
        if (tblent->oldval == oldv) {
            tblent->newval = newv;
            return;
        }
    }
    Newxz(tblent, 1, PTR_TBL_ENT_t);
    tblent->oldval = oldv;
    tblent->newval = newv;
    tblent->next = *otblent;
    *otblent = tblent;
    tbl->tbl_items++;
    if (i && tbl->tbl_items > tbl->tbl_max)
        modperl_svptr_table_split(aTHX_ tbl);
}

/* double the hash bucket size of an existing ptr table */

void
modperl_svptr_table_split(pTHX_ PTR_TBL_t *tbl)
{
    PTR_TBL_ENT_t **ary = tbl->tbl_ary;
    UV oldsize = tbl->tbl_max + 1;
    UV newsize = oldsize * 2;
    UV i;

    Renew(ary, newsize, PTR_TBL_ENT_t*);
    Zero(&ary[oldsize], newsize-oldsize, PTR_TBL_ENT_t*);
    tbl->tbl_max = --newsize;
    tbl->tbl_ary = ary;
    for (i=0; i < oldsize; i++, ary++) {
        PTR_TBL_ENT_t **curentp, **entp, *ent;
        if (!*ary)
            continue;
        curentp = ary + oldsize;
        for (entp = ary, ent = *ary; ent; ent = *entp) {
            if ((newsize & PTR2UV(ent->oldval)) != i) {
                *entp = ent->next;
                ent->next = *curentp;
                *curentp = ent;
                continue;
            }
            else
                entp = &ent->next;
        }
    }
}

/* remove all the entries from a ptr table */

void
modperl_svptr_table_clear(pTHX_ PTR_TBL_t *tbl)
{
    register PTR_TBL_ENT_t **array;
    register PTR_TBL_ENT_t *entry;
    register PTR_TBL_ENT_t *oentry = (PTR_TBL_ENT_t *)NULL;
    UV riter = 0;
    UV max;

    if (!tbl || !tbl->tbl_items) {
        return;
    }

    array = tbl->tbl_ary;
    entry = array[0];
    max = tbl->tbl_max;

    for (;;) {
        if (entry) {
            oentry = entry;
            entry = entry->next;
            Safefree(oentry);
        }
        if (!entry) {
            if (++riter > max) {
                break;
            }
            entry = array[riter];
        }
    }

    tbl->tbl_items = 0;
}

/* clear and free a ptr table */

void
modperl_svptr_table_free(pTHX_ PTR_TBL_t *tbl)
{
    if (!tbl) {
        return;
    }
    modperl_svptr_table_clear(aTHX_ tbl);
    Safefree(tbl->tbl_ary);
    Safefree(tbl);
}
