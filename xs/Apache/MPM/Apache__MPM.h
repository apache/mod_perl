static MP_INLINE SV *mpxs_Apache__MPM_query(pTHX_ SV *self, int query_code)
{
    int mpm_query_info;

    apr_status_t retval = ap_mpm_query(query_code, &mpm_query_info);

    if (retval == APR_SUCCESS) {
        return newSViv(mpm_query_info);
    }

    return &PL_sv_undef;
}

static void mpxs_Apache__MPM_BOOT(pTHX)
{
    /* implement Apache::MPM->show as a constant subroutine
     * since this information will never
     * change during an interpreter's lifetime */

    MP_TRACE_g(MP_FUNC, "defined Apache::MPM->show() as %s\n",
               ap_show_mpm());

    newCONSTSUB(PL_defstash, "Apache::MPM::show",
                newSVpv(ap_show_mpm(), 0));
}
