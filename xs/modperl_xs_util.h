/* Copyright 2001-2004 The Apache Software Foundation
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

#ifndef MODPERL_XS_H
#define MODPERL_XS_H

/* XXX: should be part of generation */
#undef mp_xs_sv2_r /* defined in modperl_xs_sv_convert.h */
#define mp_xs_sv2_r(sv) modperl_sv2request_rec(aTHX_ sv)

#undef mp_xs_sv2_APR__Table
#define mp_xs_sv2_APR__Table(sv)                                        \
    (apr_table_t *)modperl_hash_tied_object(aTHX_ "APR::Table", sv)

#define mpxs_Apache__RequestRec_pool(r) r->pool
#define mpxs_Apache__Connection_pool(c) c->pool
#define mpxs_Apache__URI_pool(u)        ((modperl_uri_t *)u)->pool
#define mpxs_APR__URI_pool(u)           ((modperl_uri_t *)u)->pool

#ifndef dAX
#    define dAX    I32 ax = mark - PL_stack_base + 1
#endif

#ifndef dITEMS
#    define dITEMS I32 items = SP - MARK
#endif

#define mpxs_PPCODE(code) STMT_START {          \
    SP -= items;                                \
    code;                                       \
    PUTBACK;                                    \
} STMT_END

#define PUSHs_mortal_iv(iv) PUSHs(sv_2mortal(newSViv(iv)))
#define PUSHs_mortal_pv(pv) PUSHs(sv_2mortal(newSVpv((char *)pv,0)))

#define XPUSHs_mortal_iv(iv) EXTEND(SP, 1); PUSHs_mortal_iv(iv)
#define XPUSHs_mortal_pv(pv) EXTEND(SP, 1); PUSHs_mortal_pv(pv)

/* XXX: replace the old mpxs_sv_ macros with MP_Sv macros */

#define mpxs_sv_grow(sv, len)    MP_SvGROW(sv, len)

#define mpxs_sv_cur_set(sv, len) MP_SvCUR_set(sv, len)

#define mpxs_set_targ(func, arg)                \
    STMT_START {                                \
    dXSTARG;                                    \
    XSprePUSH;                                  \
    func(aTHX_ TARG, arg);                      \
    PUSHTARG;                                   \
    XSRETURN(1);                                \
} STMT_END

#define mpxs_cv_name()                          \
    HvNAME(GvSTASH(CvGV(cv))), GvNAME(CvGV(cv))

#define mpxs_sv_is_object(sv)                           \
    (SvROK(sv) && (SvTYPE(SvRV(sv)) == SVt_PVMG))

#define mpxs_sv_object_deref(sv, type)                            \
    (mpxs_sv_is_object(sv) ? (type *)SvIVX((SV*)SvRV(sv)) : NULL)

#define mpxs_sv2_obj(obj, sv)                   \
    (obj = mp_xs_sv2_##obj(sv))

#define mpxs_usage_items_1(arg)                 \
    if (items != 1) {                           \
        Perl_croak(aTHX_ "usage: %s::%s(%s)",   \
                   mpxs_cv_name(), arg);        \
    }

#define mpxs_usage_va(i, obj, msg)                      \
    if ((items < i) || !(mpxs_sv2_obj(obj, *MARK))) {   \
        Perl_croak(aTHX_ "usage: %s", msg);             \
    }                                                   \
    MARK++

#define mpxs_usage_va_1(obj, msg) mpxs_usage_va(1, obj, msg)

#define mpxs_usage_va_2(obj, arg, msg)          \
    mpxs_usage_va(2, obj, msg);                 \
    arg = *MARK++

#define mpxs_write_loop(func, obj, name)                        \
    while (MARK <= SP) {                                        \
        apr_size_t wlen;                                        \
        char *buf = SvPV(*MARK, wlen);                          \
        MP_TRACE_o(MP_FUNC, "%d bytes [%s]", wlen, buf);        \
        MP_RUN_CROAK(func(aTHX_ obj, buf, &wlen), name);        \
        bytes += wlen;                                          \
        MARK++;                                                 \
    }

/* several methods need to ensure that the pool that they take as an
 * object doesn't go out of scope before the object that they return,
 * since if this happens, the data contained in the later object
 * becomes corrupted. this macro is used in various xs files where
 * it's needed */
#if ((PERL_REVISION == 5) && (PERL_VERSION >= 8))
    /* modperl_hash_tie already attached another _ext magic under
     * 5.8+, so must use sv_magicext to have two magics with the
     * type  */
#define mpxs_add_pool_magic(obj, pool_obj)                              \
    sv_magicext(SvRV(obj), pool_obj, PERL_MAGIC_ext, NULL, Nullch, -1)
#else
#define mpxs_add_pool_magic(obj)                                        \
    sv_magic(SvRV(obj), pool_obj, PERL_MAGIC_ext, Nullch, -1)
#endif

#endif /* MODPERL_XS_H */
