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
    /* implement Apache::MPM->show and Apache::MPM->is_threaded
     * as constant subroutines, since this information will never
     * change during an interpreter's lifetime */

    int mpm_query_info;

    apr_status_t retval = ap_mpm_query(AP_MPMQ_IS_THREADED, &mpm_query_info);

    if (retval == APR_SUCCESS) {
        MP_TRACE_g(MP_FUNC, "defined Apache::MPM->is_threaded() as %i\n", 
                   mpm_query_info);

        newCONSTSUB(PL_defstash, "Apache::MPM::is_threaded",
                    newSViv(mpm_query_info));
    }
    else {
        /* assign false (0) to sub if ap_mpm_query didn't succeed */
        MP_TRACE_g(MP_FUNC, "defined Apache::MPM->is_threaded() as 0\n");

        newCONSTSUB(PL_defstash, "Apache::MPM::is_threaded",
                    newSViv(0));
    }

    MP_TRACE_g(MP_FUNC, "defined Apache::MPM->show() as %s\n",
               ap_show_mpm());

    newCONSTSUB(PL_defstash, "Apache::MPM::show",
                newSVpv(ap_show_mpm(), 0));
}
