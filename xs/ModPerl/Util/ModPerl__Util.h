static MP_INLINE void mpxs_ModPerl__Util_untaint(pTHX_ I32 items,
                                                 SV **MARK, SV **SP)
{
    while (MARK <= SP) {
        SvTAINTED_off(*MARK++);
    }
}
