static MP_INLINE void mpxs_apr_base64_encode(pTHX_ SV *sv, SV *arg)
{
    STRLEN len;
    int encoded_len;
    char *data = SvPV(arg, len);
    mpxs_sv_grow(sv, apr_base64_encode_len(len));
    encoded_len = apr_base64_encode_binary(SvPVX(sv), data, len);
    mpxs_sv_cur_set(sv, encoded_len);
}

static MP_INLINE void mpxs_apr_base64_decode(pTHX_ SV *sv, SV *arg)
{
    STRLEN len;
    int decoded_len;
    char *data = SvPV(arg, len);
    mpxs_sv_grow(sv, apr_base64_decode_len(data));
    decoded_len = apr_base64_decode_binary(SvPVX(sv), data);
    mpxs_sv_cur_set(sv, decoded_len);
}

static XS(MPXS_apr_base64_encode)
{
    dXSARGS;

    mpxs_usage_items_1("data");

    mpxs_set_targ(mpxs_apr_base64_encode, ST(0));
}

static XS(MPXS_apr_base64_decode)
{
    dXSARGS;

    mpxs_usage_items_1("data");

    mpxs_set_targ(mpxs_apr_base64_decode, ST(0));
}
