/* Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
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
    modperl_bucket_sv_t *svbucket = bucket->data;
    dTHXa(svbucket->perl);
    STRLEN svlen;
    char *pv = SvPV(svbucket->sv, svlen);

    *str = pv + bucket->start;
    *len = bucket->length;

    if (svlen < bucket->start + bucket->length) {
        /* XXX log error? */
        return APR_EGENERAL;
    }

    return APR_SUCCESS;
}

static void modperl_bucket_sv_destroy(void *data)
{
    modperl_bucket_sv_t *svbucket = data;
    dTHXa(svbucket->perl);

    if (!apr_bucket_shared_destroy(svbucket)) {
        MP_TRACE_f(MP_FUNC, "bucket refcnt=%d",
                   ((apr_bucket_refcount *)svbucket)->refcount);
        return;
    }

    MP_TRACE_f(MP_FUNC, "sv=0x%lx, refcnt=%d",
               (unsigned long)svbucket->sv, SvREFCNT(svbucket->sv));

    SvREFCNT_dec(svbucket->sv);

    apr_bucket_free(svbucket);
}

static
apr_status_t modperl_bucket_sv_setaside(apr_bucket *bucket, apr_pool_t *pool)
{
    modperl_bucket_sv_t *svbucket = bucket->data;
    dTHXa(svbucket->perl);
    STRLEN svlen;
    char *pv = SvPV(svbucket->sv, svlen);

    if (svlen < bucket->start + bucket->length) {
        /* XXX log error? */
        return APR_EGENERAL;
    }

    pv = apr_pstrmemdup(pool, pv + bucket->start, bucket->length);
    if (pv == NULL) {
        return APR_ENOMEM;
    }

    /* changes bucket guts by reference */
    if (apr_bucket_pool_make(bucket, pv, bucket->length, pool) == NULL) {
        return APR_ENOMEM;
    }

    modperl_bucket_sv_destroy(svbucket);
    return APR_SUCCESS;
}

static const apr_bucket_type_t modperl_bucket_sv_type = {
    "mod_perl SV bucket", 4,
#if MODULE_MAGIC_NUMBER >= 20020602
    APR_BUCKET_DATA,
#endif
    modperl_bucket_sv_destroy,
    modperl_bucket_sv_read,
    modperl_bucket_sv_setaside,
    apr_bucket_shared_split,
    apr_bucket_shared_copy,
};

static apr_bucket *modperl_bucket_sv_make(pTHX_
                                          apr_bucket *bucket,
                                          SV *sv,
                                          apr_off_t offset,
                                          apr_size_t len)
{
    modperl_bucket_sv_t *svbucket;

    svbucket = apr_bucket_alloc(sizeof(*svbucket), bucket->list);

    bucket = apr_bucket_shared_make(bucket, svbucket, offset, len);
    if (!bucket) {
        apr_bucket_free(svbucket);
        return NULL;
    }

    /* XXX: need to deal with PerlInterpScope */
#ifdef USE_ITHREADS
    svbucket->perl = aTHX;
#endif

    /* PADTMP SVs belong to perl and can't be stored away, since perl
     * is going to reuse them, so we have no choice but to copy the
     * data away, before storing sv */
    if (SvPADTMP(sv)) {
        STRLEN len;
        char *pv = SvPV(sv, len);
        svbucket->sv = newSVpvn(pv, len);
    }
    else {
        svbucket->sv = sv;
        (void)SvREFCNT_inc(svbucket->sv);
    }

    MP_TRACE_f(MP_FUNC, "sv=0x%lx, refcnt=%d",
               (unsigned long)svbucket->sv, SvREFCNT(svbucket->sv));

    bucket->type = &modperl_bucket_sv_type;
    return bucket;
}

apr_bucket *modperl_bucket_sv_create(pTHX_ apr_bucket_alloc_t *list, SV *sv,
                                     apr_off_t offset, apr_size_t len)
{
    apr_bucket *bucket;

    bucket = apr_bucket_alloc(sizeof(*bucket), list);
    APR_BUCKET_INIT(bucket);
    bucket->list = list;
    bucket->free = apr_bucket_free;
    return modperl_bucket_sv_make(aTHX_ bucket, sv, offset, len);
}
