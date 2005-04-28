
/* Copyright 2000-2005 The Apache Software Foundation
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

#include "modperl_common_includes.h"

#ifndef MODPERL_COMMON_UTIL_H
#define MODPERL_COMMON_UTIL_H

#ifdef MP_DEBUG
#define MP_INLINE
#else
#define MP_INLINE APR_INLINE
#endif

#ifdef CYGWIN
#define MP_STATIC
#else
#define MP_STATIC static
#endif

#ifdef WIN32
#   define MP_FUNC_T(name)          (_stdcall *name)
#   define MP_FUNC_NONSTD_T(name)   (*name)
/* XXX: not all functions get inlined
 * so its unclear what to and not to include in the .def files
 */
#   undef MP_INLINE
#   define MP_INLINE
#else
#   define MP_FUNC_T(name)          (*name)
#   define MP_FUNC_NONSTD_T(name)   (*name)
#endif


#define MP_SSTRLEN(string) (sizeof(string)-1)

#ifndef strcaseEQ
#   define strcaseEQ(s1,s2) (!strcasecmp(s1,s2))
#endif
#ifndef strncaseEQ
#   define strncaseEQ(s1,s2,l) (!strncasecmp(s1,s2,l))
#endif

#ifndef SvCLASS
#define SvCLASS(o) HvNAME(SvSTASH(SvRV(o)))
#endif

#define SvObjIV(o) SvIV((SV*)SvRV(o))
#define MgObjIV(m) SvIV((SV*)SvRV(m->mg_obj))

#define MP_SvGROW(sv, len) \
    (void)SvUPGRADE(sv, SVt_PV); \
    SvGROW(sv, len+1)

#define MP_SvCUR_set(sv, len) \
    SvCUR_set(sv, len); \
    *SvEND(sv) = '\0'; \
    SvPOK_only(sv)

#define MP_magical_untie(sv, mg_flags) \
    mg_flags = SvMAGICAL((SV*)sv); \
    SvMAGICAL_off((SV*)sv)

#define MP_magical_tie(sv, mg_flags) \
    SvFLAGS((SV*)sv) |= mg_flags


/* tie %hash */
MP_INLINE SV *modperl_hash_tie(pTHX_ const char *classname,
                               SV *tsv, void *p);

/* tied %hash */
MP_INLINE SV *modperl_hash_tied_object_rv(pTHX_ 
                                          const char *classname,
                                          SV *tsv);
/* tied %hash */
MP_INLINE void *modperl_hash_tied_object(pTHX_ const char *classname,
                                         SV *tsv);

MP_INLINE SV *modperl_perl_sv_setref_uv(pTHX_ SV *rv,
                                        const char *classname, UV uv);

MP_INLINE modperl_uri_t *modperl_uri_new(apr_pool_t *p);

SV *modperl_perl_gensym(pTHX_ char *pack);

/*** ithreads enabled perl CLONE support ***/
#define MP_CLONE_DEBUG 1

#define MP_CLONE_HASH_NAME "::CLONE_objects"
#define MP_CLONE_HASH_NAME1 "CLONE_objects"
#define MP_CLONE_HASH_LEN1 13

/* some classes like APR::Table get the key in a different way and
 * therefore should redefine this define */
#define MP_CLONE_KEY_COMMON(obj) SvIVX(SvRV(obj))

#define MP_CLONE_GET_HV(namespace)                                      \
    get_hv(Perl_form(aTHX_ "%s::%s", namespace, MP_CLONE_HASH_NAME), TRUE);

#if MP_CLONE_DEBUG

#define MP_CLONE_DEBUG_INSERT_KEY(namespace, obj)                       \
    Perl_warn(aTHX_ "%s %p: insert %s, %p => %p",                       \
              namespace, aTHX_ SvPV_nolen(sv_key), obj, SvRV(obj));

#define MP_CLONE_DEBUG_HOLLOW_KEY(namespace)                            \
    Perl_warn(aTHX_ "%s %p: hollow %s", namespace,                      \
              aTHX_ SvPVX(hv_iterkeysv(he)));

#define MP_CLONE_DEBUG_DELETE_KEY(namespace)                            \
    Perl_warn(aTHX_ "%s %p: delete %s", namespace, aTHX_ SvPVX(sv_key));

#define MP_CLONE_DEBUG_CLONE(namespace)                                 \
    Perl_warn(aTHX_ "%s %p: CLONE called", namespace, aTHX);

#define MP_CLONE_DUMP_OBJECTS_HASH(namespace)                           \
    {                                                                   \
        HE *he;                                                         \
        HV *hv = MP_CLONE_GET_HV(namespace);                            \
        Perl_warn(aTHX_ "%s %p: DUMP", namespace, aTHX);                \
        hv_iterinit(hv);                                                \
        while ((he = hv_iternext(hv))) {                                \
            SV *key = hv_iterkeysv(he);                                 \
            SV *val = hv_iterval(hv, he);                               \
            Perl_warn(aTHX_ "\t%s => %p => %p\n", SvPVX(key),           \
                      val, SvRV(val));                                  \
        }                                                               \
    }

#else /* if MP_CLONE_DEBUG */

#define MP_CLONE_DEBUG_INSERT_KEY(namespace, obj)
#define MP_CLONE_DEBUG_HOLLOW_KEY(namespace)
#define MP_CLONE_DEBUG_DELETE_KEY(namespace)
#define MP_CLONE_DEBUG_CLONE(namespace)
#define MP_CLONE_DUMP_OBJECTS_HASH(namespace)

#endif /* if MP_CLONE_DEBUG */

#ifdef SvWEAKREF
#define WEAKEN(sv) sv_rvweaken(sv)
#else
#error "weak references are not implemented in this release of perl");
#endif

#define MP_CLONE_INSERT_OBJ(namespace, obj)                             \
    {                                                                   \
        SV *weak_rv, *sv_key;                                           \
        /* $objects{"$$self"} = $self;                                  \
           Scalar::Util::weaken($objects{"$$self"})                     \
        */                                                              \
        HV *hv = MP_CLONE_GET_HV(namespace);                            \
/* use the real object pointer as a unique key */                       \
        sv_key = newSVpvf("%p", MP_CLONE_KEY_COMMON((obj)));            \
        MP_CLONE_DEBUG_INSERT_KEY("a", (obj));                  \
        weak_rv = newRV(SvRV((obj)));                                   \
        WEAKEN(weak_rv); /* à la Scalar::Util::weaken */                 \
        {                                                               \
            HE *ok = hv_store_ent(hv, sv_key, weak_rv, FALSE);          \
            sv_free(sv_key);                                            \
            if (ok == NULL) {                                           \
                SvREFCNT_dec(weak_rv);                                  \
                Perl_croak(aTHX_ "failed to insert into %%%s::%s",      \
                           namespace, MP_CLONE_HASH_NAME);              \
            }                                                           \
            MP_CLONE_DUMP_OBJECTS_HASH(namespace);                      \
        }                                                               \
    }

#define MP_CLONE_DO_CLONE(namespace, class)                             \
    {                                                                   \
        HE *he;                                                         \
        HV *hv = MP_CLONE_GET_HV(namespace);                            \
        MP_CLONE_DEBUG_CLONE(namespace);                                \
        MP_CLONE_DUMP_OBJECTS_HASH(namespace);                          \
        hv_iterinit(hv);                                                \
        while ((he = hv_iternext(hv))) {                                \
            SV *rv = hv_iterval(hv, he);                                \
            SV *sv = SvRV(rv);                                          \
            /* sv_dump(rv); */                                          \
            MP_CLONE_DEBUG_HOLLOW_KEY(namespace);                       \
            if (sv) {                                                   \
                /* detach from the C struct and invalidate */           \
                mg_free(sv); /* remove any magic */                     \
                SvFLAGS(sv) = 0;  /* invalidate the sv */               \
                /*  sv_free(sv); */                                     \
            }                                                           \
            /* sv_dump(sv); */                                          \
            /* sv_dump(rv); */                                          \
            SV *sv_key = hv_iterkeysv(he);                              \
            hv_delete_ent(hv, sv_key, G_DISCARD, FALSE);                \
        }                                                               \
        MP_CLONE_DUMP_OBJECTS_HASH(namespace);                          \
        class = class; /* unused */                                     \
    }

/* obj: SvRV'd object */
#define MP_CLONE_DELETE_OBJ(namespace, obj)                             \
    {                                                                   \
        HV *hv = MP_CLONE_GET_HV(namespace);                            \
        SV *sv_key = newSVpvf("%p", MP_CLONE_KEY_COMMON(obj));          \
        /* delete $CLONE_objects{"$$self"}; */                          \
        MP_CLONE_DEBUG_DELETE_KEY(namespace);                           \
        hv_delete_ent(hv, sv_key, G_DISCARD, FALSE);                    \
        sv_free(sv_key);                                                \
        MP_CLONE_DUMP_OBJECTS_HASH(namespace);                          \
    }

#endif /* MODPERL_COMMON_UTIL_H */

