static MP_INLINE void mpxs_ModPerl__Util_untaint(pTHX_ I32 items,
                                                 SV **MARK, SV **SP)
{
    while (MARK <= SP) {
        SvTAINTED_off(*MARK++);
    }
}

#define mpxs_ModPerl__Util_exit(status) modperl_perl_exit(aTHX_ status)
