static MP_INLINE int mpxs_ap_run_sub_req(pTHX_ request_rec *r)
{
    /* need to flush main request output buffer if any
     * before running any subrequests, else we get subrequest
     * output before anything already written in the main request
     */

    if (r->main) {
        modperl_config_req_t *rcfg =
            modperl_config_req_get(r->main);
        modperl_wbucket_flush(rcfg->wbucket);
    }

    return ap_run_sub_req(r);
}
