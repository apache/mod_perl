void modperl_process_callback(int idx, ap_context_t *p, server_rec *s);

void modperl_files_callback(int idx,
                            ap_context_t *pconf, ap_context_t *plog,
                            ap_context_t *ptemp, server_rec *s);

int modperl_per_dir_callback(int idx, request_rec *r);

int modperl_per_srv_callback(int idx, request_rec *r);

int modperl_connection_callback(int idx, conn_rec *c);
