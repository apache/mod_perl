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

    int full_len;
    (void)SvPV(sv, full_len);

    if (len) {
        if (len > full_len - offset) {
            Perl_croak(aTHX_ "APR::Bucket::new: the length argument can't be"
                       " bigger than the total buffer length minus offset");
        }
    }
    else {
        len = full_len - offset;
    }
    
    return modperl_bucket_sv_create(aTHX_ sv, offset, len);
}

static MP_INLINE SV *mpxs_APR__Bucket_read(pTHX_
                                           apr_bucket *bucket,
                                           apr_read_type_e block)
{
    SV *buf;
    apr_size_t len;
    const char *str;
    apr_status_t rc = apr_bucket_read(bucket, &str, &len, block);
    
    if (rc == APR_EOF) {
        return newSVpvn("", 0);
    }

    if (rc != APR_SUCCESS) {
        modperl_croak(aTHX_ rc, "APR::Bucket::read");  
    }

    /* XXX: bug in perl, newSVpvn(NULL, 0) doesn't produce "" sv */
    if (len) {
        buf = newSVpvn(str, len);
    }
    else {
        buf = newSVpvn("", 0);
    }
    
    SvTAINTED_on(buf);
    
    return buf;
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

