#ifndef MODPERL_XS_H
#define MODPERL_XS_H

#ifndef dAX
#    define dAX    I32 ax = mark - PL_stack_base + 1
#endif

#ifndef dITEMS
#    define dITEMS I32 items = SP - MARK
#endif

#define mpxs_PPCODE(code) STMT_START { \
    SP -= items; \
    code; \
    PUTBACK; \
} STMT_END

#define PUSHs_mortal_iv(iv) PUSHs(sv_2mortal(newSViv(iv)))
#define PUSHs_mortal_pv(pv) PUSHs(sv_2mortal(newSVpv((char *)pv,0)))

#define mpxs_sv_grow(sv, len) \
    (void)SvUPGRADE(sv, SVt_PV); \
    SvGROW(sv, len+1)

#define mpxs_sv_cur_set(sv, len) \
    SvCUR_set(sv, len); \
    *SvEND(sv) = '\0'; \
    SvPOK_only(sv)

#define mpxs_set_targ(func, arg) \
STMT_START { \
    dXSTARG; \
    XSprePUSH; \
    func(aTHX_ TARG, arg); \
    PUSHTARG; \
    XSRETURN(1); \
} STMT_END

#define mpxs_cv_name() \
HvNAME(GvSTASH(CvGV(cv))), GvNAME(CvGV(cv))

#define mpxs_sv_is_object(sv) \
(SvROK(sv) && (SvTYPE(SvRV(sv)) == SVt_PVMG))

#define mpxs_sv_object_deref(sv, type) \
(mpxs_sv_is_object(sv) ? (type *)SvIVX((SV*)SvRV(sv)) : NULL)

#define mpxs_sv2_obj(obj, sv) \
(obj = mp_xs_sv2_##obj(sv))

#define mpxs_usage_items_1(arg) \
if (items != 1) { \
    Perl_croak(aTHX_ "usage: %s::%s(%s)", \
               mpxs_cv_name(), arg); \
}

#define mpxs_usage_va(i, obj, msg) \
if ((items < i) || !(mpxs_sv2_obj(obj, *MARK))) \
croak("usage: %s", msg); \
MARK++

#define mpxs_usage_va_1(obj, msg) mpxs_usage_va(1, obj, msg)

#define mpxs_usage_va_2(obj, arg, msg) \
mpxs_usage_va(2, obj, msg); \
arg = *MARK++

#define mpxs_write_loop(func,obj) \
    while (MARK <= SP) { \
        apr_ssize_t wlen; \
        char *buf = SvPV(*MARK, wlen); \
        apr_status_t rv = func(obj, buf, &wlen); \
        if (rv != APR_SUCCESS) { \
            croak(modperl_apr_strerror(rv)); \
        } \
        bytes += wlen; \
        MARK++; \
    }

#endif /* MODPERL_XS_H */
