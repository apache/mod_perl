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

static MP_INLINE
SV *mpxs_APR__Socket_recv(pTHX_ apr_socket_t *socket, int len)
{
    SV *buf = NEWSV(0, len);
    apr_status_t rc = apr_socket_recv(socket, SvPVX(buf), &len);

    if (len > 0) {
        mpxs_sv_cur_set(buf, len);
        SvTAINTED_on(buf);
    } 
    else if (rc == APR_EOF) {
        sv_setpvn(buf, "", 0);
    }
    else if (rc != APR_SUCCESS) {
        SvREFCNT_dec(buf);
        modperl_croak(aTHX_ rc, "APR::Socket::recv");  
    }
    
    return buf;
}

static MP_INLINE
apr_size_t mpxs_apr_socket_send(pTHX_ apr_socket_t *socket,
                                SV *sv_buf, SV *sv_len)
{
    apr_size_t buf_len;
    char *buffer = SvPV(sv_buf, buf_len);

    if (sv_len) {
        if (buf_len < SvIV(sv_len)) {
            Perl_croak(aTHX_ "the 3rd arg (%d) is bigger than the "
                       "length (%d) of the 2nd argument",
                       SvIV(sv_len), buf_len);
        }
        buf_len = SvIV(sv_len);
    }

    MP_RUN_CROAK(apr_socket_send(socket, buffer, &buf_len),
                 "APR::Socket::send");

    return buf_len;
}

static MP_INLINE
apr_interval_time_t mpxs_apr_socket_timeout_get(pTHX_ I32 items,
                                                SV **MARK, SV **SP)
{
    apr_interval_time_t	t;
    APR__Socket APR__Socket;

    /* this also magically assings to APR_Socket ;-) */
    mpxs_usage_va_1(APR__Socket, "$socket->timeout_get()");

    MP_FAILURE_CROAK(apr_socket_timeout_get(APR__Socket, &t));

    return t;
}

static MP_INLINE
void mpxs_APR__Socket_timeout_set(pTHX_ apr_socket_t *socket,
                                 apr_interval_time_t t)
{
    MP_FAILURE_CROAK(apr_socket_timeout_set(socket, t));
}



static MP_INLINE
apr_int32_t mpxs_APR__Socket_opt_get(pTHX_ apr_socket_t *socket,
                                     apr_int32_t opt)
{
    apr_int32_t val;
    MP_FAILURE_CROAK(apr_socket_opt_get(socket, opt, &val));
    return val;
}

static MP_INLINE
void mpxs_APR__Socket_opt_set(pTHX_ apr_socket_t *socket, apr_int32_t opt,
                              apr_int32_t val)
{
    MP_FAILURE_CROAK(apr_socket_opt_set(socket, opt, val));
}
