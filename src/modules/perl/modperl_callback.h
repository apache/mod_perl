#ifndef MODPERL_CALLBACK_H
#define MODPERL_CALLBACK_H

void modperl_process_callback(int idx, ap_pool_t *p, server_rec *s);

void modperl_files_callback(int idx,
                            ap_pool_t *pconf, ap_pool_t *plog,
                            ap_pool_t *ptemp, server_rec *s);

int modperl_per_dir_callback(int idx, request_rec *r);

int modperl_per_srv_callback(int idx, request_rec *r);

int modperl_connection_callback(int idx, conn_rec *c);

#endif /* MODPERL_CALLBACK_H */
