#ifndef MODPERL_FILTER_H
#define MODPERL_FILTER_H

#define MODPERL_OUTPUT_FILTER_NAME "MODPERL_OUTPUT"
#define MODPERL_INPUT_FILTER_NAME  "MODPERL_INPUT"

#define MP_FILTER_CONNECTION_HANDLER 0x01
#define MP_FILTER_REQUEST_HANDLER    0x02

/* simple buffer api */
MP_INLINE apr_status_t modperl_wbucket_pass(modperl_wbucket_t *b,
                                            const char *buf, apr_ssize_t len);

MP_INLINE apr_status_t modperl_wbucket_flush(modperl_wbucket_t *b);

MP_INLINE apr_status_t modperl_wbucket_write(modperl_wbucket_t *b,
                                             const char *buf,
                                             apr_ssize_t *wlen);

/* generic filter routines */

modperl_filter_t *modperl_filter_new(ap_filter_t *f,
                                     apr_bucket_brigade *bb,
                                     modperl_filter_mode_e mode);

modperl_filter_t *modperl_filter_mg_get(pTHX_ SV *obj);

int modperl_run_filter(modperl_filter_t *filter, ap_input_mode_t mode,
                       apr_off_t *readbytes);

/* output filters */
apr_status_t modperl_output_filter_handler(ap_filter_t *f,
                                           apr_bucket_brigade *bb);

void modperl_output_filter_register_connection(conn_rec *c);

void modperl_output_filter_register_request(request_rec *r);

MP_INLINE apr_status_t modperl_output_filter_flush(modperl_filter_t *filter);

MP_INLINE apr_ssize_t modperl_output_filter_read(pTHX_
                                                 modperl_filter_t *filter,
                                                 SV *buffer,
                                                 apr_ssize_t wanted);

MP_INLINE apr_status_t modperl_output_filter_write(modperl_filter_t *filter,
                                                   const char *buf,
                                                   apr_ssize_t *len);

void modperl_brigade_dump(apr_bucket_brigade *bb, FILE *fp);

/* input filters */
apr_status_t modperl_input_filter_handler(ap_filter_t *f,
                                          apr_bucket_brigade *bb,
                                          ap_input_mode_t mode,
                                          apr_off_t *readbytes);

void modperl_input_filter_register_connection(conn_rec *c);

void modperl_input_filter_register_request(request_rec *r);

#endif /* MODPERL_FILTER_H */
