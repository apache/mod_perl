#define mpxs_Apache__OutputFilter_f(filter) filter->f

#define mpxs_Apache__RequestRec_add_output_filter(r, name, ctx) \
ap_add_output_filter(name, ctx, r, NULL)

/* XXX: this should be generated like the others in modperl_xs_sv_convert.h */
#define mp_xs_sv2_modperl_filter(sv) \
((SvROK(sv) && (SvTYPE(SvRV(sv)) == SVt_PVMG)) \
|| (Perl_croak(aTHX_ "argument is not a blessed reference"),0) ? \
(modperl_filter_t *)SvIV((SV*)SvRV(sv)) : (modperl_filter_t *)NULL)

static MP_INLINE apr_size_t mpxs_Apache__OutputFilter_print(pTHX_ I32 items,
                                                            SV **MARK, SV **SP)
{
    modperl_filter_t *modperl_filter;
    apr_size_t bytes = 0;

    mpxs_usage_va_1(modperl_filter, "$filter->print(...)");

    if (modperl_filter->mode == MP_OUTPUT_FILTER_MODE) {
        mpxs_write_loop(modperl_output_filter_write, modperl_filter);
        modperl_output_filter_flush(modperl_filter);
    }
    else {
        croak("input filters not yet supported");
    }

    /* XXX: ap_rflush if $| */

    return bytes;
}

static MP_INLINE apr_size_t mpxs_Apache__OutputFilter_read(pTHX_ I32 items,
                                                           SV **MARK, SV **SP)
{
    modperl_filter_t *modperl_filter;
    apr_size_t wanted, len=0;
    SV *buffer;

    mpxs_usage_va_2(modperl_filter, buffer, "$filter->read(buf, [len])");

    if (items > 2) {
        wanted = SvIV(*MARK);
    }
    else {
        wanted = MP_IOBUFSIZE;
    }

    if (modperl_filter->mode == MP_OUTPUT_FILTER_MODE) {
        len = modperl_output_filter_read(aTHX_ modperl_filter, buffer, wanted);
    }
    else {
        croak("input filters not yet supported");
    }

    return len;
}

static MP_INLINE I32 *modperl_filter_attributes(SV *package, SV *cvrv)
{
    return &MP_CODE_ATTRS(SvRV(cvrv));
}

static XS(MPXS_modperl_filter_attributes)
{
    dXSARGS;
    I32 *attrs = modperl_filter_attributes(ST(0), ST(1));
    I32 i;

    for (i=2; i < items; i++) {
        STRLEN len;
        char *pv = SvPV(ST(i), len);
        char *attribute = pv;

        switch (*pv) {
          case 'I':
            if (strnEQ(pv, "InputFilter", 11)) {
                pv += 11;
                switch (*pv) {
                  case 'B':
                    if (strEQ(pv, "Body")) {
                        *attrs |= MP_INPUT_FILTER_BODY;
                        continue;
                    }
                  case 'M':
                    if (strEQ(pv, "Message")) {
                        *attrs |= MP_INPUT_FILTER_MESSAGE;
                        continue;
                    }
                }
            }
          default:
            XPUSHs_mortal_pv(attribute);
            XSRETURN(1);
        }
    }

    XSRETURN_EMPTY;
}
