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
