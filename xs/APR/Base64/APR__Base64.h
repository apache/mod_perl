/* Copyright 2001-2005 The Apache Software Foundation
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

static MP_INLINE void mpxs_apr_base64_encode(pTHX_ SV *sv, SV *arg)
{
    STRLEN len;
    int encoded_len;
    char *data = SvPV(arg, len);
    mpxs_sv_grow(sv, apr_base64_encode_len(len));
    encoded_len = apr_base64_encode_binary(SvPVX(sv), data, len);
    mpxs_sv_cur_set(sv, encoded_len);
}

static MP_INLINE void mpxs_apr_base64_decode(pTHX_ SV *sv, SV *arg)
{
    STRLEN len;
    int decoded_len;
    char *data = SvPV(arg, len);
    mpxs_sv_grow(sv, apr_base64_decode_len(data));
    decoded_len = apr_base64_decode_binary(SvPVX(sv), data);
    mpxs_sv_cur_set(sv, decoded_len);
}

MP_STATIC XS(MPXS_apr_base64_encode)
{
    dXSARGS;

    mpxs_usage_items_1("data");

    mpxs_set_targ(mpxs_apr_base64_encode, ST(0));
}

MP_STATIC XS(MPXS_apr_base64_decode)
{
    dXSARGS;

    mpxs_usage_items_1("data");

    mpxs_set_targ(mpxs_apr_base64_decode, ST(0));
}
