static MP_INLINE
apr_socket_t *mpxs_Apache__Connection_client_socket(pTHX_ conn_rec *c,
                                                    apr_socket_t *s)
{
    apr_socket_t *socket =
        ap_get_module_config(c->conn_config, &core_module);

    if (s) {
        ap_set_module_config(c->conn_config, &core_module, s);
    }

    return socket;
}

static MP_INLINE
const char *mpxs_Apache__Connection_get_remote_host(pTHX_ conn_rec *c,
                                                    int type,
                                                    ap_conf_vector_t *dir_config)
{
    return ap_get_remote_host(c, (void *)dir_config, type, NULL);
}
