static MP_INLINE apr_status_t mpxs_apr_recv(pTHX_ apr_socket_t *socket,
                                            SV *sv_buf, SV *sv_len)
{
    apr_status_t status;
    apr_size_t len = mp_xs_sv2_apr_size_t(sv_len);

    mpxs_sv_grow(sv_buf, len);
    status = apr_recv(socket, SvPVX(sv_buf), &len);
    mpxs_sv_cur_set(sv_buf, len);

    if (!SvREADONLY(sv_len)) {
        sv_setiv(sv_len, len);
    }

    return status;
}

static MP_INLINE apr_status_t mpxs_apr_send(pTHX_ apr_socket_t *socket,
                                            SV *sv_buf, SV *sv_len)
{
    apr_status_t status;
    apr_size_t buf_len;
    char *buffer = SvPV(sv_buf, buf_len);

    if (sv_len) {
        buf_len = SvIV(sv_len);
    }

    status = apr_send(socket, buffer, &buf_len);

    if (sv_len && !SvREADONLY(sv_len)) {
        sv_setiv(sv_len, buf_len);
    }

    return status;
}

static MP_INLINE apr_interval_time_t
mpxs_apr_socket_timeout_get(pTHX_ I32 items, SV **MARK, SV **SP)
{
    apr_interval_time_t	t;
    APR__Socket APR__Socket;

    /* this also magically assings to APR_Socket ;-) */
    mpxs_usage_va_1(APR__Socket, "$socket->timeout_get()");

    MP_FAILURE_CROAK(apr_socket_timeout_get(APR__Socket, &t));

    return t;
}

