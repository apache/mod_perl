#ifndef MODPERL_FILTER_H
#define MODPERL_FILTER_H

#define MODPERL_OUTPUT_FILTER_NAME "MODPERL_OUTPUT"

/* simple buffer api */
MP_INLINE apr_status_t modperl_wbucket_pass(modperl_wbucket_t *b,
                                            const char *buf, apr_ssize_t len);

MP_INLINE apr_status_t modperl_wbucket_flush(modperl_wbucket_t *b);

MP_INLINE apr_status_t modperl_wbucket_write(modperl_wbucket_t *b,
                                             const char *buf,
                                             apr_ssize_t *wlen);

/* generic filter routines */

modperl_filter_t *modperl_filter_new(ap_filter_t *f,
                                     ap_bucket_brigade *bb,
                                     modperl_filter_mode_e mode);

int modperl_run_filter(modperl_filter_t *filter);

MP_INLINE modperl_filter_t *modperl_sv2filter(pTHX_ SV *sv);

/* output filters */
apr_status_t modperl_output_filter_handler(ap_filter_t *f,
                                           ap_bucket_brigade *bb);

void modperl_output_filter_register(request_rec *r);

MP_INLINE apr_status_t modperl_output_filter_flush(modperl_filter_t *filter);

MP_INLINE apr_ssize_t modperl_output_filter_read(pTHX_
                                                 modperl_filter_t *filter,
                                                 SV *buffer,
                                                 apr_ssize_t wanted);

MP_INLINE apr_status_t modperl_output_filter_write(modperl_filter_t *filter,
                                                   const char *buf,
                                                   apr_ssize_t *len);

void modperl_brigade_dump(ap_bucket_brigade *bb, FILE *fp);

#endif /* MODPERL_FILTER_H */
