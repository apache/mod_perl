/* Copyright 2002-2004 The Apache Software Foundation
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

static MP_INLINE int mpxs_apr_password_validate(pTHX_ const char *passwd,
                                                const char *hash)
{
    return apr_password_validate(passwd, hash) == APR_SUCCESS;
}

static MP_INLINE void mpxs_apr_strerror(pTHX_ SV *sv, SV *arg)
{
    apr_status_t statcode = mp_xs_sv2_status(arg);
    char *ptr;
    mpxs_sv_grow(sv, 128-1);
    ptr = apr_strerror(statcode, SvPVX(sv), SvLEN(sv));
    mpxs_sv_cur_set(sv, strlen(ptr)); /*XXX*/
}

static XS(MPXS_apr_strerror)
{
    dXSARGS;

    mpxs_usage_items_1("status_code");

    mpxs_set_targ(mpxs_apr_strerror, ST(0));
}
