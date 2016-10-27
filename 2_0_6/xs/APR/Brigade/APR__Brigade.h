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

static MP_INLINE
void mpxs_APR__Brigade_cleanup(apr_bucket_brigade *brigade)
{
    /* apr has a broken prototype (passing 'void *' instead of
     * 'apr_bucket_brigade *', so use a wrapper here */
    apr_brigade_cleanup(brigade);
}

static MP_INLINE
SV *mpxs_apr_brigade_create(pTHX_ SV *CLASS, SV *p_sv,
                            apr_bucket_alloc_t *ba)
{
    apr_pool_t *p = mp_xs_sv2_APR__Pool(p_sv);
    apr_bucket_brigade *bb = apr_brigade_create(p, ba);
    SV *bb_sv = sv_setref_pv(NEWSV(0, 0), "APR::Brigade", (void*)bb);
    mpxs_add_pool_magic(bb_sv, p_sv);
    return bb_sv;
}

#define get_brigade(brigade, fetch) \
(fetch(brigade) == APR_BRIGADE_SENTINEL(brigade) ? \
 NULL : fetch(brigade))

static MP_INLINE
apr_bucket *mpxs_APR__Brigade_first(apr_bucket_brigade *brigade)
{
    return get_brigade(brigade, APR_BRIGADE_FIRST);
}

static MP_INLINE
apr_bucket *mpxs_APR__Brigade_last(apr_bucket_brigade *brigade)
{
    return get_brigade(brigade, APR_BRIGADE_LAST);
}

#define get_bucket(brigade, bucket, fetch) \
(fetch(bucket) == APR_BRIGADE_SENTINEL(brigade) ? \
 NULL : fetch(bucket))

static MP_INLINE
apr_bucket *mpxs_APR__Brigade_next(apr_bucket_brigade *brigade,
                                    apr_bucket *bucket)
{
    return get_bucket(brigade, bucket, APR_BUCKET_NEXT);
}

static MP_INLINE
apr_bucket *mpxs_APR__Brigade_prev(apr_bucket_brigade *brigade,
                                   apr_bucket *bucket)
{
    return get_bucket(brigade, bucket, APR_BUCKET_PREV);
}

static MP_INLINE
void mpxs_APR__Brigade_insert_tail(apr_bucket_brigade *brigade,
                                   apr_bucket *bucket)
{
    APR_BRIGADE_INSERT_TAIL(brigade, bucket);
}

static MP_INLINE
void mpxs_APR__Brigade_insert_head(apr_bucket_brigade *brigade,
                                   apr_bucket *bucket)
{
    APR_BRIGADE_INSERT_HEAD(brigade, bucket);
}

static MP_INLINE
void mpxs_APR__Brigade_concat(apr_bucket_brigade *a,
                              apr_bucket_brigade *b)
{
    APR_BRIGADE_CONCAT(a, b);
}

static MP_INLINE
int mpxs_APR__Brigade_is_empty(apr_bucket_brigade *brigade)
{
    return APR_BRIGADE_EMPTY(brigade);
}

static MP_INLINE
apr_pool_t *mpxs_APR__Brigade_pool(apr_bucket_brigade *brigade)
{
    /* eesh, it's r->pool, and c->pool, but bb->p
     * let's make Perl consistent, otherwise this could be autogenerated
     */

    return brigade->p;
}

static MP_INLINE
SV *mpxs_APR__Brigade_length(pTHX_ apr_bucket_brigade *bb,
                             int read_all)
{
    apr_off_t length;

    apr_status_t rv = apr_brigade_length(bb, read_all, &length);

    /* XXX - we're deviating from the API here a bit in order to
     * make it more perlish - returning the length instead of
     * the return code.  maybe that's not such a good idea, though...
     */
    if (rv == APR_SUCCESS) {
        return newSViv((int)length);
    }

    return &PL_sv_undef;
}

#define mp_xs_sv2_bb mp_xs_sv2_APR__Brigade

static MP_INLINE
apr_size_t mpxs_APR__Brigade_flatten(pTHX_ I32 items,
                                     SV **MARK, SV **SP)
{

    apr_bucket_brigade *bb;
    apr_size_t wanted;
    apr_status_t rc;
    SV *buffer;

    mpxs_usage_va_2(bb, buffer, "$bb->flatten($buf, [$wanted])");

    if (items > 2) {
        /* APR::Brigade->flatten($wanted); */
        wanted = SvIV(*MARK);
    }
    else {
        /* APR::Brigade->flatten(); */
        /* can't use pflatten, because we can't realloc() memory
         * allocated by pflatten. and we need to append '\0' to it in
         * SvPVX.  so we copy pflatten's guts here.
         */
        apr_off_t actual;
        apr_brigade_length(bb, 1, &actual);
        wanted = (apr_size_t)actual;
    }

    (void)SvUPGRADE(buffer, SVt_PV);
    mpxs_sv_grow(buffer, wanted);

    rc = apr_brigade_flatten(bb, SvPVX(buffer), &wanted);
    if (!(rc == APR_SUCCESS || rc == APR_EOF)) {
        modperl_croak(aTHX_ rc, "APR::Brigade::flatten");
    }

    mpxs_sv_cur_set(buffer, wanted);
    SvTAINTED_on(buffer);

    return wanted;
}

static MP_INLINE
void mpxs_APR__Brigade_destroy(pTHX_ apr_bucket_brigade *bb)
{
    MP_RUN_CROAK(apr_brigade_destroy(bb), "APR::Brigade::destroy");
}