/*
 * XXX: these three should be part of the apache api
 * for protocol module helpers
 */

static MP_INLINE request_rec *mpxs_Apache__RequestRec_new(SV *classname,
                                                          conn_rec *c)
{
    apr_pool_t *p;
    request_rec *r;
    server_rec *s = c->base_server;

    apr_pool_create(&p, c->pool);
    r = apr_pcalloc(p, sizeof(request_rec));

    r->pool = p;
    r->connection = c;
    r->server = s;

    r->hostname = s->server_hostname;
    r->request_config = ap_create_request_config(p);
    r->per_dir_config = s->lookup_defaults;
    r->method = "GET";
    r->method_number = M_GET;
    r->uri = "/";
    r->filename = (char *)ap_server_root_relative(p, r->uri);

    r->the_request = "UNKNOWN";
    r->assbackwards = 1;
    r->protocol = "UNKNOWN";

    r->status = HTTP_OK;

    r->headers_in = apr_table_make(p, 1);
    r->headers_out = apr_table_make(p, 1);
    r->err_headers_out = apr_table_make(p, 1);
    r->notes = apr_table_make(p, 1);

    return r;
}

static MP_INLINE int mpxs_Apache__RequestRec_location_merge(request_rec *r,
                                                            char *location)
{
    apr_pool_t *p = r->pool;
    server_rec *s = r->server;
    core_server_config *sconf = ap_get_module_config(s->module_config,
                                                     &core_module);
    ap_conf_vector_t **sec = (ap_conf_vector_t **)sconf->sec_url->elts;
    int num_sec = sconf->sec_url->nelts;
    int i;

    for (i=0; i<num_sec; i++) {
        core_dir_config *entry =
            (core_dir_config *)ap_get_module_config(sec[i],
                                                    &core_module);

        if (strEQ(entry->d, location)) {
            if (!entry->ap_auth_type) {
                entry->ap_auth_type = "Basic";
            }
            if (!entry->ap_auth_name) {
                entry->ap_auth_name = apr_pstrdup(p, location);
            }
            r->per_dir_config =
                ap_merge_per_dir_configs(p, s->lookup_defaults, sec[i]);
            return 1;
        }
    }

    return 0;
}

static MP_INLINE void
mpxs_Apache__RequestRec_set_basic_credentials(request_rec *r,
                                              char *username,
                                              char *password)
{
    char encoded[1024];
    int elen;
    char *auth_value, *auth_cat;

    auth_cat = apr_pstrcat(r->pool,
                           username, ":", password, NULL);
    elen = apr_base64_encode(encoded, auth_cat, strlen(auth_cat));
    encoded[elen] = '\0';

    auth_value = apr_pstrcat(r->pool, "Basic ", encoded, NULL);
    apr_table_setn(r->headers_in, "Authorization", auth_value);
}
