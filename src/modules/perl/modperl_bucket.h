#ifndef MODPERL_BUCKET_H
#define MODPERL_BUCKET_H

apr_bucket *modperl_bucket_sv_create(pTHX_ SV *sv, int offset, int len);

#endif /* MODPERL_BUCKET_H */
