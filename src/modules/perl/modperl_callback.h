#ifndef MODPERL_CALLBACK_H
#define MODPERL_CALLBACK_H

/* alias some hook names to match Perl*Handler names */
#define ap_hook_trans  ap_hook_translate_name
#define ap_hook_access ap_hook_access_checker
#define ap_hook_authen ap_hook_check_user_id
#define ap_hook_authz  ap_hook_auth_checker
#define ap_hook_type   ap_hook_type_checker
#define ap_hook_fixup  ap_hook_fixups
#define ap_hook_log    ap_hook_log_transaction

int modperl_callback(pTHX_ modperl_handler_t *handler, apr_pool_t *p,
                     request_rec *r, server_rec *s, AV *args);

int modperl_callback_run_handlers(int idx, int type,
                                  request_rec *r, conn_rec *c, server_rec *s,
                                  apr_pool_t *pconf,
                                  apr_pool_t *plog,
                                  apr_pool_t *ptemp);

int modperl_callback_per_dir(int idx, request_rec *r);

int modperl_callback_per_srv(int idx, request_rec *r);

int modperl_callback_connection(int idx, conn_rec *c);

void modperl_callback_process(int idx, apr_pool_t *p, server_rec *s);

int modperl_callback_files(int idx,
                           apr_pool_t *pconf, apr_pool_t *plog,
                           apr_pool_t *ptemp, server_rec *s);

#endif /* MODPERL_CALLBACK_H */
