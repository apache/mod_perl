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

/* This file must not contain any symbols from apache/mod_perl (apr
 *  and perl are OK). Also try to keep all the mod_perl specific
 *  functions (even if they don't contain symbols from apache/mod_perl
 *  on in modperl_util.c, unless we want them elsewhere. That is
 *  needed in order to keep the libraries used outside mod_perl
 *  small  */

#include "modperl_common_util.h"

/* Prefetch magic requires perl 5.8 */
#if MP_PERL_VERSION_AT_LEAST(5, 8, 0)

/* A custom MGVTBL with mg_copy slot filled in allows us to FETCH a
 * table entry immediately during iteration.  For multivalued keys
 * this is essential in order to get the value corresponding to the
 * current key, otherwise values() will always report the first value
 * repeatedly.  With this MGVTBL the keys() list always matches up
 * with the values() list, even in the multivalued case.  We only
 * prefetch the value during iteration, because the prefetch adds
 * overhead (an unnecessary FETCH call) to EXISTS and STORE
 * operations.  This way they are only "penalized" when the perl
 * program is iterating via each(), which seems to be a reasonable
 * tradeoff.
 */

MP_INLINE static
int modperl_table_magic_copy(pTHX_ SV *sv, MAGIC *mg, SV *nsv,
                             const char *name, int namelen)
{
    /* prefetch the value whenever we're iterating over the keys */
    MAGIC *tie_magic = mg_find(nsv, PERL_MAGIC_tiedelem);
    SV *obj = SvRV(tie_magic->mg_obj);
    if (SvCUR(obj)) {
        SvGETMAGIC(nsv);
    }
    return 0;
}


static const MGVTBL modperl_table_magic_prefetch = {0, 0, 0, 0, 0,
                                                    modperl_table_magic_copy};
#endif /* End of prefetch magic */

MP_INLINE SV *modperl_hash_tie(pTHX_
                               const char *classname,
                               SV *tsv, void *p)
{
    SV *hv = (SV*)newHV();
    SV *rsv = sv_newmortal();

    sv_setref_pv(rsv, classname, p);

    /* Prefetch magic requires perl 5.8 */
#if MP_PERL_VERSION_AT_LEAST(5, 8, 0)

    sv_magicext(hv, NULL, PERL_MAGIC_ext, NULL, (char *)NULL, -1);
    SvMAGIC(hv)->mg_virtual = (MGVTBL *)&modperl_table_magic_prefetch;
    SvMAGIC(hv)->mg_flags |= MGf_COPY;

#endif /* End of prefetch magic */

    sv_magic(hv, rsv, PERL_MAGIC_tied, (char *)NULL, 0);

    return SvREFCNT_inc(sv_bless(sv_2mortal(newRV_noinc(hv)),
                                 gv_stashpv(classname, TRUE)));
}

MP_INLINE SV *modperl_hash_tied_object_rv(pTHX_
                                          const char *classname,
                                          SV *tsv)
{
    if (sv_derived_from(tsv, classname)) {
        if (SVt_PVHV == SvTYPE(SvRV(tsv))) {
            SV *hv = SvRV(tsv);
            MAGIC *mg;

            if (SvMAGICAL(hv)) {
                if ((mg = mg_find(hv, PERL_MAGIC_tied))) {
                    return mg->mg_obj;
                }
                else {
                    Perl_warn(aTHX_ "Not a tied hash: (magic=%c)", mg->mg_type);
                }
            }
            else {
                Perl_warn(aTHX_ "SV is not tied");
            }
        }
        else {
            return tsv;
        }
    }
    else {
        Perl_croak(aTHX_
                   "argument is not a blessed reference "
                   "(expecting an %s derived object)", classname);
    }

    return &PL_sv_undef;
}

MP_INLINE void *modperl_hash_tied_object(pTHX_
                                         const char *classname,
                                         SV *tsv)
{
    SV *rv = modperl_hash_tied_object_rv(aTHX_ classname, tsv);
    if (SvROK(rv)) {
        return INT2PTR(void *, SvIVX(SvRV(rv)));
    }
    else {
        return NULL;
    }
}

/* same as Symbol::gensym() */
SV *modperl_perl_gensym(pTHX_ char *pack)
{
    GV *gv = newGVgen(pack);
    SV *rv = newRV((SV*)gv);
    (void)hv_delete(gv_stashpv(pack, TRUE),
                    GvNAME(gv), GvNAMELEN(gv), G_DISCARD);
    return rv;
}

/* XXX: sv_setref_uv does not exist in 5.6.x */
MP_INLINE SV *modperl_perl_sv_setref_uv(pTHX_ SV *rv,
                                        const char *classname, UV uv)
{
    sv_setuv(newSVrv(rv, classname), uv);
    return rv;
}

MP_INLINE modperl_uri_t *modperl_uri_new(apr_pool_t *p)
{
    modperl_uri_t *uri = (modperl_uri_t *)apr_pcalloc(p, sizeof(*uri));
    uri->pool = p;
    return uri;
}
