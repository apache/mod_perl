/* Copyright 2001-2004 The Apache Software Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "modperl_bucket.h"

static apr_bucket *mpxs_APR__Bucket_new(pTHX_ SV *classname, SV *sv,
                                        int offset, int len)
{
    if (!len) {
        (void)SvPV(sv, len);
    }

    return modperl_bucket_sv_create(aTHX_ sv, offset, len);
}

/* this is just so C::Scan will pickup the prototype */
static MP_INLINE apr_status_t modperl_bucket_read(apr_bucket *bucket,
                                                  const char **str,
                                                  apr_size_t *len,
                                                  apr_read_type_e block)
{
    return apr_bucket_read(bucket, str, len, block);
}

static MP_INLINE apr_status_t mpxs_modperl_bucket_read(pTHX_
                                                       apr_bucket *bucket,
                                                       SV *buffer,
                                                       apr_read_type_e block)
{
    int rc;
    apr_size_t len;
    const char *str;

    rc = modperl_bucket_read(bucket, &str, &len, block);

    if ((rc != APR_SUCCESS) && (rc != APR_EOF)) {
        /* XXX: croak ? */
    }

    sv_setpvn(buffer, str, len);

    return rc;
}

static MP_INLINE int mpxs_APR__Bucket_is_eos(apr_bucket *bucket)
{
    return APR_BUCKET_IS_EOS(bucket);
}

static MP_INLINE int mpxs_APR__Bucket_is_flush(apr_bucket *bucket)
{
    return APR_BUCKET_IS_FLUSH(bucket);
}

static MP_INLINE void mpxs_APR__Bucket_insert_before(apr_bucket *a,
                                                     apr_bucket *b)
{
    APR_BUCKET_INSERT_BEFORE(a, b);
}

static MP_INLINE void mpxs_APR__Bucket_insert_after(apr_bucket *a,
                                                    apr_bucket *b)
{
    APR_BUCKET_INSERT_AFTER(a, b);
}

static MP_INLINE void mpxs_APR__Bucket_remove(apr_bucket *bucket)
{
    APR_BUCKET_REMOVE(bucket);
}

