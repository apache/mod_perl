/* Copyright 2001-2005 The Apache Software Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

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

static MP_INLINE void mpxs_insert_auth_cfg(pTHX_ request_rec *r,
                                           char *directive,
                                           char *val)
{
    const char *errmsg;
    AV *config = newAV();

    av_push(config, Perl_newSVpvf(aTHX_ "%s %s", directive, val));

    errmsg =
        modperl_config_insert_request(aTHX_ r,
                                      newRV_noinc((SV*)config),
                                      OR_AUTHCFG);

    if (errmsg) {
        Perl_warn(aTHX_ "Can't change %s to '%s'\n", directive, val);
    }

    SvREFCNT_dec((SV*)config);
}

static MP_INLINE
const char *mpxs_Apache2__RequestRec_auth_type(pTHX_ request_rec *r,
                                              char *type)
{
    if (type) {
        mpxs_insert_auth_cfg(aTHX_ r, "AuthType", type);
    }

    return ap_auth_type(r);
}

static MP_INLINE
const char *mpxs_Apache2__RequestRec_auth_name(pTHX_ request_rec *r,
                                              char *name)
{
    if (name) {
        mpxs_insert_auth_cfg(aTHX_ r, "AuthName", name);
    }

    return ap_auth_name(r);
}

static XS(MPXS_ap_get_basic_auth_pw)
{
    dXSARGS;
    request_rec *r;
    const char *sent_pw = NULL;
    int rc;

    mpxs_usage_items_1("r");

    mpxs_PPCODE({
        r = mp_xs_sv2_r(ST(0));

        /* Default auth-type to Basic */
        if (!ap_auth_type(r)) {
            mpxs_Apache2__RequestRec_auth_type(aTHX_ r, "Basic");
        }

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
