#include "mod_perl.h"

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
