static MP_INLINE
apr_socket_t *mpxs_Apache__Connection_client_socket(pTHX_ conn_rec *c,
                                                    apr_socket_t *s)
{
    /* XXX: until minds are made up */
#if 0
    apr_socket_t *socket =
        ap_get_module_config(c->conn_config, &core_module);

    if (s) {
        ap_set_module_config(c->conn_config, &core_module, s);
    }

    return socket;
#else
    if (s) {
        c->client_socket = s;
    }

    return c->client_socket;
#endif
}
