#include "mod_perl.h"

int modperl_require_module(pTHX_ const char *pv)
{
    SV *sv;

    dSP;
    PUSHSTACKi(PERLSI_REQUIRE);
    PUTBACK;
    sv = sv_newmortal();
    sv_setpv(sv, "require ");
    sv_catpv(sv, pv);
    eval_sv(sv, G_DISCARD);
    SPAGAIN;
    POPSTACK;

    return SvTRUE(ERRSV) ? FALSE : TRUE;
}

MP_INLINE request_rec *modperl_sv2request_rec(pTHX_ SV *sv)
{
    request_rec *r = NULL;

    if (SvROK(sv) && (SvTYPE(SvRV(sv)) == SVt_PVMG)) {
        r = (request_rec *)SvIV((SV*)SvRV(sv));
    }

    return r;
}

MP_INLINE SV *modperl_ptr2obj(pTHX_ char *classname, void *ptr)
{
    SV *sv = newSV(0);

    MP_TRACE_h(MP_FUNC, "sv_setref_pv(%s, 0x%lx)\n",
               classname, (unsigned long)ptr);
    sv_setref_pv(sv, classname, ptr);

    return sv;
}

char *modperl_apr_strerror(apr_status_t rv)
{
    dTHX;
    char buf[256];
    apr_strerror(rv, buf, sizeof(buf));
    return Perl_form(aTHX_ "%d:%s", rv, buf);
}

int modperl_errsv(pTHX_ int status, request_rec *r, server_rec *s)
{
    SV *sv = ERRSV;
    STRLEN n_a;

    if (SvTRUE(sv)) {
        if (SvMAGICAL(sv) && (SvCUR(sv) > 4) &&
            strnEQ(SvPVX(sv), " at ", 4))
        {
            /* Apache::exit was called */
            return DECLINED;
        }
#if 0
        if (modperl_sv_is_http_code(ERRSV, &status)) {
            return status;
        }
#endif
        if (r) {
            ap_log_rerror(APLOG_MARK, APLOG_ERR, 0, r, SvPV(sv, n_a));
        }
        else {
            ap_log_error(APLOG_MARK, APLOG_ERR, 0, s, SvPV(sv, n_a));
        }

        return status;
    }

    return status;
}
