static XS(MPXS_ap_get_basic_auth_pw)
{
    dXSARGS;
    request_rec *r;
    const char *sent_pw = NULL;
    int rc;

    mpxs_usage_items_1("r");

    mpxs_PPCODE({
        r = mp_xs_sv2_r(ST(0));

        rc = ap_get_basic_auth_pw(r, &sent_pw);

        EXTEND(SP, 2);
        PUSHs_mortal_iv(rc);
        if (rc == OK) {
            PUSHs_mortal_pv(sent_pw);
        }
        else {
            PUSHs(&PL_sv_undef);
        }
    });
}

static MP_INLINE SV *mpxs_ap_requires(pTHX_ request_rec *r)
{
    AV *av;
    HV *hv;
    register int x;
    const apr_array_header_t *reqs_arr = ap_requires(r);
    require_line *reqs;

    if (!reqs_arr) {
        return &PL_sv_undef;
    }

    reqs = (require_line *)reqs_arr->elts;
    av = newAV();

    for (x=0; x < reqs_arr->nelts; x++) {
        /* XXX should we do this or let PerlAuthzHandler? */
        if (! (reqs[x].method_mask & (1 << r->method_number))) {
            continue;
        }

        hv = newHV();

        hv_store(hv, "method_mask", 11, 
                 newSViv((IV)reqs[x].method_mask), 0);

        hv_store(hv, "requirement", 11, 
                 newSVpv(reqs[x].requirement,0), 0);

        av_push(av, newRV_noinc((SV*)hv));
    }

    return newRV_noinc((SV*)av); 
}

static MP_INLINE
void mpxs_ap_allow_methods(pTHX_ I32 items, SV **MARK, SV **SP)
{
    request_rec *r;
    SV *reset;

    mpxs_usage_va_2(r, reset, "$r->allow_methods(reset, ...)");

    if (SvIV(reset)) {
        ap_clear_method_list(r->allowed_methods);
    }

    while (MARK <= SP) {
        STRLEN n_a;
        char *method = SvPV(*MARK, n_a);
        ap_method_list_add(r->allowed_methods, method);
        MARK++;
    }
}

                                            
