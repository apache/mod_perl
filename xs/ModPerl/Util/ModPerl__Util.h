static MP_INLINE void mpxs_ModPerl__Util_untaint(pTHX_ I32 items,
                                                 SV **MARK, SV **SP)
{
    if (!PL_tainting) {
        return;
    }
    while (MARK <= SP) {
        sv_untaint(*MARK++);
    }
}

#define mpxs_ModPerl__Util_exit(status) modperl_perl_exit(aTHX_ status)
