#define mpxs_Apache__RequestRec_add_output_filter(r, name, ctx) \
ap_add_output_filter(name, ctx, r, NULL)

#define mpxs_Apache__RequestRec_add_input_filter(r, name, ctx) \
ap_add_output_filter(name, ctx, r, NULL)

#define mp_xs_sv2_modperl_filter(sv) \
((SvROK(sv) && (SvTYPE(SvRV(sv)) == SVt_PVMG)) \
|| (Perl_croak(aTHX_ "argument is not a blessed reference"),0) ? \
modperl_filter_mg_get(aTHX_ sv) : NULL)

#define mpxs_Apache__Filter_TIEHANDLE(stashsv, sv) \
modperl_newSVsv_obj(aTHX_ stashsv, sv)

#define mpxs_Apache__Filter_PRINT mpxs_Apache__Filter_print

static MP_INLINE apr_size_t mpxs_Apache__Filter_print(pTHX_ I32 items,
                                                      SV **MARK, SV **SP)
{
    modperl_filter_t *modperl_filter;
    apr_size_t bytes = 0;

    mpxs_usage_va_1(modperl_filter, "$filter->print(...)");

    if (modperl_filter->mode == MP_OUTPUT_FILTER_MODE) {
        mpxs_write_loop(modperl_output_filter_write, modperl_filter);
    }
    else {
        croak("input filters not yet supported");
    }

    /* XXX: ap_rflush if $| */

    return bytes;
}

static MP_INLINE apr_size_t mpxs_Apache__Filter_read(pTHX_ I32 items,
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

static apr_status_t mpxs_ap_get_brigade(pTHX_ ap_filter_t *filter,
                                        apr_bucket_brigade *brigade,
                                        ap_input_mode_t mode,
                                        SV *svreadbytes)
{
    apr_off_t readbytes = svreadbytes ? SvIV(svreadbytes) : 0;
    apr_status_t status = ap_get_brigade(filter, brigade, mode, &readbytes);

    if (svreadbytes) {
        sv_setiv(svreadbytes, readbytes);
    }

    return status;
}

static MP_INLINE U32 *modperl_filter_attributes(SV *package, SV *cvrv)
{
    return (U32 *)&MP_CODE_ATTRS(SvRV(cvrv));
}

#ifdef MP_TRACE
#define trace_attr() \
MP_TRACE_f(MP_FUNC, "applied %s attribute to %s handler\n", attribute, \
           HvNAME(stash))
#else
#define trace_attr()
#endif

static XS(MPXS_modperl_filter_attributes)
{
    dXSARGS;
    U32 *attrs = modperl_filter_attributes(ST(0), ST(1));
    I32 i;
#ifdef MP_TRACE
    HV *stash = gv_stashsv(ST(0), TRUE);
#endif

    for (i=2; i < items; i++) {
        STRLEN len;
        char *pv = SvPV(ST(i), len);
        char *attribute = pv;

        if (strnEQ(pv, "Filter", 6)) {
            pv += 6;
        }

        switch (*pv) {
          case 'C':
            if (strEQ(pv, "ConnectionHandler")) {
                *attrs |= MP_FILTER_CONNECTION_HANDLER;
                trace_attr();
                continue;
            }
          case 'R':
            if (strEQ(pv, "RequestHandler")) {
                *attrs |= MP_FILTER_REQUEST_HANDLER;
                trace_attr();
                continue;
            }
          default:
            XPUSHs_mortal_pv(attribute);
            XSRETURN(1);
        }
    }

    XSRETURN_EMPTY;
}
