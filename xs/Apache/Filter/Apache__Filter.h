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
        mpxs_write_loop(modperl_input_filter_write, modperl_filter);
    }

    /* XXX: ap_rflush if $| */

    return bytes;
}

static MP_INLINE apr_size_t mpxs_Apache__Filter_read(pTHX_ I32 items,
                                                     SV **MARK, SV **SP)
{
    modperl_filter_t *modperl_filter;
    ap_input_mode_t mode = 0;
    apr_read_type_e block = 0;
    apr_off_t readbytes = 0;
    apr_size_t wanted, len=0;
    SV *buffer;
    
    if (items < 4) {
        mpxs_usage_va_2(modperl_filter, buffer, "$filter->read(buf, [len])");
    }
    else {
        modperl_filter = mp_xs_sv2_modperl_filter(*MARK); MARK++;
        mode           = (ap_input_mode_t)SvIV(*MARK); MARK++;
        block          = (apr_read_type_e)SvIV(*MARK); MARK++;
        readbytes      = (apr_off_t)SvIV(*MARK); MARK++;
        buffer         = *MARK++;
    }
        
    if (items == 3 || items == 6) {
        wanted = SvIV(*MARK);
    }
    else {
        wanted = MP_IOBUFSIZE;
    }

    if (modperl_filter->mode == MP_INPUT_FILTER_MODE) {
        len = modperl_input_filter_read(aTHX_ modperl_filter, mode,
                                        block, readbytes, buffer, wanted);
    }
    else {
        len = modperl_output_filter_read(aTHX_ modperl_filter, buffer, wanted);
    }

    return len;
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

static MP_INLINE SV *mpxs_Apache__Filter_ctx(pTHX_
                                             ap_filter_t *filter,
                                             SV *data)
{
    modperl_filter_ctx_t *ctx = (modperl_filter_ctx_t *)(filter->ctx);

    if (data != Nullsv) {
        ctx->data = SvREFCNT_inc(data);
    }

    return ctx->data ? SvREFCNT_inc(ctx->data) : &PL_sv_undef;
}

static MP_INLINE SV *mpxs_Apache__Filter_seen_eos(pTHX_ I32 items,
                                                  SV **MARK, SV **SP)
{
    modperl_filter_t *modperl_filter;
    mpxs_usage_va_1(modperl_filter, "$filter->seen_eos()");
    return modperl_filter->seen_eos ? &PL_sv_yes : &PL_sv_no;
}

static MP_INLINE
void mpxs_Apache__RequestRec_add_input_filter(pTHX_ request_rec *r,
                                              SV *callback)
{
    
    modperl_filter_runtime_add(aTHX_ r,
                               r->connection,
                               MP_INPUT_FILTER_HANDLER,
                               MP_FILTER_REQUEST_INPUT_NAME,
                               ap_add_input_filter,
                               callback,
                               "InputFilter");
}

static MP_INLINE
void mpxs_Apache__RequestRec_add_output_filter(pTHX_ request_rec *r,
                                               SV *callback)
{
    
    modperl_filter_runtime_add(aTHX_ r,
                               r->connection,
                               MP_OUTPUT_FILTER_HANDLER,
                               MP_FILTER_REQUEST_OUTPUT_NAME,
                               ap_add_output_filter,
                               callback,
                               "OutputFilter");
}

static MP_INLINE
void mpxs_Apache__Connection_add_input_filter(pTHX_ conn_rec *c,
                                              SV *callback)
{
    
    modperl_filter_runtime_add(aTHX_ NULL,
                               c,
                               MP_INPUT_FILTER_HANDLER,
                               MP_FILTER_CONNECTION_INPUT_NAME,
                               ap_add_input_filter,
                               callback,
                               "InputFilter");
}

static MP_INLINE
void mpxs_Apache__Connection_add_output_filter(pTHX_ conn_rec *c,
                                               SV *callback)
{
    
    modperl_filter_runtime_add(aTHX_ NULL,
                               c,
                               MP_OUTPUT_FILTER_HANDLER,
                               MP_FILTER_CONNECTION_OUTPUT_NAME,
                               ap_add_output_filter,
                               callback,
                               "OutputFilter");
}
