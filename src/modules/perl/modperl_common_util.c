/* Copyright 2000-2004 The Apache Software Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
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

MP_INLINE SV *modperl_hash_tie(pTHX_ 
                               const char *classname,
                               SV *tsv, void *p)
{
    SV *hv = (SV*)newHV();
    SV *rsv = sv_newmortal();

    sv_setref_pv(rsv, classname, p);
    sv_magic(hv, rsv, PERL_MAGIC_tied, Nullch, 0);

    return SvREFCNT_inc(sv_bless(sv_2mortal(newRV_noinc(hv)),
                                 gv_stashpv(classname, TRUE)));
}

MP_INLINE void *modperl_hash_tied_object(pTHX_ 
                                         const char *classname,
                                         SV *tsv)
{
    if (sv_derived_from(tsv, classname)) {
        if (SVt_PVHV == SvTYPE(SvRV(tsv))) {
            SV *hv = SvRV(tsv);
            MAGIC *mg;

            if (SvMAGICAL(hv)) {
                if ((mg = mg_find(hv, PERL_MAGIC_tied))) {
                    return (void *)MgObjIV(mg);
                }
                else {
                    Perl_warn(aTHX_ "Not a tied hash: (magic=%c)", mg);
                }
            }
            else {
                Perl_warn(aTHX_ "SV is not tied");
            }
        }
        else {
            return (void *)SvObjIV(tsv);
        }
    }
    else {
        Perl_croak(aTHX_
                   "argument is not a blessed reference "
                   "(expecting an %s derived object)", classname);
    }

    return NULL;
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
