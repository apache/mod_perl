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

#include "mod_perl.h"

/*
 * modperl_bucket_sv code derived from mod_snake's ModSnakePyBucket
 * by Jon Travis
 */

typedef struct {
    apr_bucket_refcount refcount;
    SV *sv;
    PerlInterpreter *perl;
} modperl_bucket_sv_t;

static apr_status_t
modperl_bucket_sv_read(apr_bucket *bucket, const char **str,
                       apr_size_t *len, apr_read_type_e block)
{
    modperl_bucket_sv_t *svbucket =
        (modperl_bucket_sv_t *)bucket->data;
    dTHXa(svbucket->perl);
    STRLEN n_a;
    char *pv = SvPV(svbucket->sv, n_a);

    *str = pv + bucket->start;
    *len = bucket->length;

    return APR_SUCCESS;
}

static void modperl_bucket_sv_destroy(void *data)
{
    modperl_bucket_sv_t *svbucket = 
        (modperl_bucket_sv_t *)data;
    dTHXa(svbucket->perl);

    if (!apr_bucket_shared_destroy(svbucket)) {
        MP_TRACE_f(MP_FUNC, "bucket refcnt=%d\n",
                   ((apr_bucket_refcount *)svbucket)->refcount);
        return;
    }

    MP_TRACE_f(MP_FUNC, "sv=0x%lx, refcnt=%d\n",
               (unsigned long)svbucket->sv, SvREFCNT(svbucket->sv));

    SvREFCNT_dec(svbucket->sv);

    free(svbucket);
}

static const apr_bucket_type_t modperl_bucket_sv_type = {
    "mod_perl SV bucket", 4,
#if MODULE_MAGIC_NUMBER >= 20020602
    APR_BUCKET_DATA,
#endif
    modperl_bucket_sv_destroy,
    modperl_bucket_sv_read,
    apr_bucket_setaside_notimpl,
    apr_bucket_shared_split,
    apr_bucket_shared_copy,
};

static apr_bucket *modperl_bucket_sv_make(pTHX_
                                          apr_bucket *bucket,
                                          SV *sv,
                                          int offset, int len)
{
    modperl_bucket_sv_t *svbucket; 

    svbucket = (modperl_bucket_sv_t *)malloc(sizeof(*svbucket));

    bucket = apr_bucket_shared_make(bucket, svbucket, offset, len);

    /* XXX: need to deal with PerlInterpScope */
#ifdef USE_ITHREADS
    svbucket->perl = aTHX;
#endif
    svbucket->sv = sv;

    if (!bucket) {
        free(svbucket);
        return NULL;
    }

    (void)SvREFCNT_inc(svbucket->sv);

    MP_TRACE_f(MP_FUNC, "sv=0x%lx, refcnt=%d\n",
               (unsigned long)sv, SvREFCNT(sv));

    bucket->type = &modperl_bucket_sv_type;
    bucket->free = free;

    return bucket;
}

apr_bucket *modperl_bucket_sv_create(pTHX_ SV *sv, int offset, int len)
{
    apr_bucket *bucket;

    bucket = (apr_bucket *)malloc(sizeof(*bucket));
    APR_BUCKET_INIT(bucket);

    return modperl_bucket_sv_make(aTHX_ bucket, sv, offset, len);
}
