static MP_INLINE void mpxs_apr_strerror(pTHX_ SV *sv, SV *arg)
{
    apr_status_t statcode = mp_xs_sv2_status(arg);
    char *ptr;
    mpxs_sv_grow(sv, 128-1);
    ptr = apr_strerror(statcode, SvPVX(sv), SvLEN(sv));
    mpxs_sv_cur_set(sv, strlen(ptr)); /*XXX*/
}

static MP_INLINE void mpxs_apr_generate_random_bytes(pTHX_ SV *sv, SV *arg)
{
    int len = (int)SvIV(arg);
    mpxs_sv_grow(sv, len);
    (void)apr_generate_random_bytes(SvPVX(sv), len);
    mpxs_sv_cur_set(sv, len);
}

static XS(MPXS_apr_strerror)
{
    dXSARGS;

    mpxs_usage_items_1("status_code");

    mpxs_set_targ(mpxs_apr_strerror, ST(0));
}

static XS(MPXS_apr_generate_random_bytes)
{
    dXSARGS;

    mpxs_usage_items_1("length");

    mpxs_set_targ(mpxs_apr_generate_random_bytes, ST(0));
}
