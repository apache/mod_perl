#include "mod_perl.h"

/* simple buffer api */

MP_INLINE apr_status_t modperl_wbucket_pass(modperl_wbucket_t *wb,
                                            const char *buf, apr_ssize_t len)
{
    apr_bucket_brigade *bb;
    apr_bucket *bucket;

    if (wb->header_parse) {
        request_rec *r = wb->r;
        const char *bodytext = NULL;
        int status = modperl_cgi_header_parse(r, (char *)buf, &bodytext);

        if (status != OK) {
            ap_log_error(APLOG_MARK, APLOG_WARNING|APLOG_NOERRNO,
                         0, r->server, "%s did not send an HTTP header",
                         r->uri);
        }
        else if (!bodytext) {
            return APR_SUCCESS;
        }

        if (bodytext) {
            len -= (bodytext - buf);
            buf = bodytext;
        }
    }

    bb = apr_brigade_create(wb->pool);
    bucket = apr_bucket_transient_create(buf, len);
    APR_BRIGADE_INSERT_TAIL(bb, bucket);

    MP_TRACE_f(MP_FUNC, "buffer length=%d\n", len);

    return ap_pass_brigade(*(wb->filters), bb);
}

MP_INLINE apr_status_t modperl_wbucket_flush(modperl_wbucket_t *wb)
{
    apr_status_t rv = APR_SUCCESS;

    if (wb->outcnt) {
        rv = modperl_wbucket_pass(wb, wb->outbuf, wb->outcnt);
        wb->outcnt = 0;
    }

    return rv;
}

MP_INLINE apr_status_t modperl_wbucket_write(modperl_wbucket_t *wb,
                                             const char *buf,
                                             apr_ssize_t *wlen)
{
    apr_ssize_t len = *wlen;
    *wlen = 0;

    if ((len + wb->outcnt) > sizeof(wb->outbuf)) {
        apr_status_t rv;
        if ((rv = modperl_wbucket_flush(wb)) != APR_SUCCESS) {
            return rv;
        }
    }

    if (len >= sizeof(wb->outbuf)) {
        *wlen = len;
        return modperl_wbucket_pass(wb, buf, len);
    }
    else {
        memcpy(&wb->outbuf[wb->outcnt], buf, len);
        wb->outcnt += len;
        *wlen = len;
        return APR_SUCCESS;
    }
}

/* generic filter routines */

#define MP_FILTER_POOL(f) f->r ? f->r->pool : f->c->pool

modperl_filter_t *modperl_filter_new(ap_filter_t *f,
                                     apr_bucket_brigade *bb,
                                     modperl_filter_mode_e mode)
{
    apr_pool_t *p = MP_FILTER_POOL(f);
    modperl_filter_t *filter = apr_pcalloc(p, sizeof(*filter));

    filter->mode = mode;
    filter->f = f;
    filter->bb = bb;
    filter->pool = p;
    filter->wbucket.pool = p;
    filter->wbucket.filters = &f->next;
    filter->wbucket.outcnt = 0;

    MP_TRACE_f(MP_FUNC, "filter=0x%lx, mode=%s\n",
               (unsigned long)filter, mode == MP_OUTPUT_FILTER_MODE ?
               "output" : "input");

    return filter;
}

static void modperl_filter_mg_set(pTHX_ SV *obj, modperl_filter_t *filter)
{
    sv_magic(SvRV(obj), Nullsv, '~', NULL, -1);
    SvMAGIC(SvRV(obj))->mg_ptr = (char *)filter;
}

modperl_filter_t *modperl_filter_mg_get(pTHX_ SV *obj)
{
    MAGIC *mg = mg_find(SvRV(obj), '~');
    return mg ? (modperl_filter_t *)mg->mg_ptr : NULL;
}

int modperl_run_filter(modperl_filter_t *filter,
                       ap_input_mode_t mode,
                       apr_read_type_e block,
                       apr_off_t readbytes)
{
    AV *args = Nullav;
    int status;
    modperl_handler_t *handler =
        ((modperl_filter_ctx_t *)filter->f->ctx)->handler;

    request_rec *r = filter->f->r;
    conn_rec    *c = filter->f->c;
    server_rec  *s = r ? r->server : c->base_server;
    apr_pool_t  *p = r ? r->pool : c->pool;

    MP_dINTERP_SELECT(r, c, s);

    modperl_handler_make_args(aTHX_ &args,
                              "Apache::Filter", filter->f,
                              "APR::Brigade", filter->bb,
                              NULL);

    modperl_filter_mg_set(aTHX_ AvARRAY(args)[0], filter);

    if (filter->mode == MP_INPUT_FILTER_MODE) {
        av_push(args, newSViv(mode));
        av_push(args, newSViv(block));
        av_push(args, newSViv(readbytes));
    }

    if ((status = modperl_callback(aTHX_ handler, p, r, s, args)) != OK) {
        status = modperl_errsv(aTHX_ status, r, s);
    }

    SvREFCNT_dec((SV*)args);

    MP_TRACE_f(MP_FUNC, "%s returned %d\n", handler->name, status);

    if (filter->mode == MP_OUTPUT_FILTER_MODE) {
        modperl_output_filter_flush(filter);
    }

    return status;
}

/* output filters */

MP_INLINE static apr_status_t send_eos(ap_filter_t *f)
{
    apr_bucket_brigade *bb = apr_brigade_create(MP_FILTER_POOL(f));
    apr_bucket *b = apr_bucket_eos_create();
    APR_BRIGADE_INSERT_TAIL(bb, b);
    return ap_pass_brigade(f->next, bb);
}

MP_INLINE static apr_status_t send_flush(ap_filter_t *f)
{
    apr_bucket_brigade *bb = apr_brigade_create(MP_FILTER_POOL(f));
    apr_bucket *b = apr_bucket_flush_create();
    APR_BRIGADE_INSERT_TAIL(bb, b);
    return ap_pass_brigade(f->next, bb);
}

/* unrolled APR_BRIGADE_FOREACH loop */

#define MP_FILTER_SENTINEL(filter) \
APR_BRIGADE_SENTINEL(filter->bb)

#define MP_FILTER_FIRST(filter) \
APR_BRIGADE_FIRST(filter->bb)

#define MP_FILTER_NEXT(filter) \
APR_BUCKET_NEXT(filter->bucket)

#define MP_FILTER_IS_EOS(filter) \
APR_BUCKET_IS_EOS(filter->bucket)

#define MP_FILTER_IS_FLUSH(filter) \
APR_BUCKET_IS_FLUSH(filter->bucket)

MP_INLINE static int get_bucket(modperl_filter_t *filter)
{
    if (!filter->bb) {
        return 0;
    }
    if (!filter->bucket) {
        filter->bucket = MP_FILTER_FIRST(filter);
        return 1;
    }
    else if (MP_FILTER_IS_EOS(filter)) {
        filter->eos = 1;
        return 1;
    }
    else if (filter->bucket != MP_FILTER_SENTINEL(filter)) {
        filter->bucket = MP_FILTER_NEXT(filter);
        if (filter->bucket == MP_FILTER_SENTINEL(filter)) {
            apr_brigade_destroy(filter->bb);
            filter->bb = NULL;
            return 0;
        }
        else {
            return 1;
        }
    }

    return 0;
}

MP_INLINE apr_ssize_t modperl_output_filter_read(pTHX_
                                                 modperl_filter_t *filter,
                                                 SV *buffer,
                                                 apr_ssize_t wanted)
{
    int num_buckets = 0;
    apr_ssize_t len = 0;

    (void)SvUPGRADE(buffer, SVt_PV);
    SvPOK_only(buffer);
    SvCUR(buffer) = 0;

    /*modperl_brigade_dump(filter->bb);*/

    MP_TRACE_f(MP_FUNC, "caller wants %d bytes\n", wanted);

    if (filter->remaining) {
        if (filter->remaining >= wanted) {
            MP_TRACE_f(MP_FUNC, "eating %d of remaining %d leftover bytes\n",
                       wanted, filter->remaining);
            sv_catpvn(buffer, filter->leftover, wanted);
            filter->leftover += wanted;
            filter->remaining -= wanted;
            return wanted;
        }
        else {
            MP_TRACE_f(MP_FUNC, "eating remaining %d leftover bytes\n",
                       filter->remaining);
            sv_catpvn(buffer, filter->leftover, filter->remaining);
            len = filter->remaining;
            filter->remaining = 0;
            filter->leftover = NULL;
        }
    }

    if (!filter->bb) {
        MP_TRACE_f(MP_FUNC, "bucket brigade has been emptied\n");
        return 0;
    }

    while (1) {
        const char *buf;
        apr_ssize_t buf_len;

        if (!get_bucket(filter)) {
            break;
        }

        if (MP_FILTER_IS_EOS(filter)) {
            MP_TRACE_f(MP_FUNC, "received EOS bucket\n");
            filter->eos = 1;
            break;
        }
        else if (MP_FILTER_IS_FLUSH(filter)) {
            MP_TRACE_f(MP_FUNC, "received FLUSH bucket\n");
            filter->flush = 1;
            break;
        }

        num_buckets++;

        filter->rc = apr_bucket_read(filter->bucket, &buf, &buf_len, 0);

        if (filter->rc == APR_SUCCESS) {
            MP_TRACE_f(MP_FUNC,
                       "bucket=%s(0x%lx) read returned %d bytes\n",
                       filter->bucket->type->name,
                       (unsigned long)filter->bucket,
                       buf_len);
        }
        else {
            MP_TRACE_f(MP_FUNC,
                       "apr_bucket_read error: %s\n",
                       modperl_apr_strerror(filter->rc));
            return len;
        }

        if (buf_len) {
            if ((SvCUR(buffer) + buf_len) >= wanted) {
                int nibble = wanted - SvCUR(buffer);
                sv_catpvn(buffer, buf, nibble);
                filter->leftover = (char *)buf+nibble;
                filter->remaining = buf_len - nibble;
                len += nibble;
                break;
            }
            else {
                len += buf_len;
                sv_catpvn(buffer, buf, buf_len);
            }
        }
    }

#ifdef MP_TRACE
    if (num_buckets) {
        MP_TRACE_f(MP_FUNC,
                   "returning %d bytes from %d bucket%s "
                   "(%d bytes leftover)\n",
                   len, num_buckets, ((num_buckets > 1) ? "s" : ""),
                   filter->remaining);
    }
#endif

    if ((filter->eos || filter->flush) && (len == 0)) {
        /* if len > 0 then $filter->write will flush */
        modperl_output_filter_flush(filter);
    }

    return len;
}

MP_INLINE apr_status_t modperl_output_filter_flush(modperl_filter_t *filter)
{
    filter->rc = modperl_wbucket_flush(&filter->wbucket);
    if (filter->rc != APR_SUCCESS) {
        return filter->rc;
    }

    if (filter->eos || filter->flush) {
        MP_TRACE_f(MP_FUNC, "sending %s bucket\n",
                   filter->eos ? "EOS" : "FLUSH");
        filter->rc = filter->eos ?
            send_eos(filter->f) : send_flush(filter->f);
        if (filter->bb) {
            apr_brigade_destroy(filter->bb);
            filter->bb = NULL;
        }
        filter->flush = filter->eos = 0;
    }

    return filter->rc;
}

MP_INLINE apr_status_t modperl_output_filter_write(modperl_filter_t *filter,
                                                   const char *buf,
                                                   apr_ssize_t *len)
{
    return modperl_wbucket_write(&filter->wbucket, buf, len);
}

#define APR_BRIGADE_IS_EOS(bb) \
APR_BUCKET_IS_EOS(APR_BRIGADE_FIRST(bb))

apr_status_t modperl_output_filter_handler(ap_filter_t *f,
                                           apr_bucket_brigade *bb)
{
    modperl_filter_t *filter;
    int status;

    if (APR_BRIGADE_IS_EOS(bb)) {
        /* XXX: see about preventing this in the first place */
        MP_TRACE_f(MP_FUNC, "first bucket is EOS, skipping callback\n");
        return ap_pass_brigade(f->next, bb);
    }
    else {
        filter = modperl_filter_new(f, bb, MP_OUTPUT_FILTER_MODE);
        status = modperl_run_filter(filter, 0, 0, 0);
    }

    switch (status) {
      case OK:
        return APR_SUCCESS;
      case DECLINED:
        return ap_pass_brigade(f->next, bb);
      default:
        return status; /*XXX*/
    }
}

apr_status_t modperl_input_filter_handler(ap_filter_t *f,
                                          apr_bucket_brigade *bb,
                                          ap_input_mode_t mode,
                                          apr_read_type_e block,
                                          apr_off_t readbytes)
{
    modperl_filter_t *filter;
    int status;

    if (APR_BRIGADE_IS_EOS(bb)) {
        /* XXX: see about preventing this in the first place */
        MP_TRACE_f(MP_FUNC, "first bucket is EOS, skipping callback\n");
        return APR_SUCCESS;
    }
    else {
        filter = modperl_filter_new(f, bb, MP_INPUT_FILTER_MODE);
        status = modperl_run_filter(filter, mode, block, readbytes);
    }

    switch (status) {
      case OK:
      case DECLINED:
        return APR_SUCCESS;
      default:
        return status; /*XXX*/
    }
}

typedef ap_filter_t * MP_FUNC_T(filter_add_t) (const char *, void *,
                                               request_rec *, conn_rec *);

static int modperl_filter_register_connection(conn_rec *c,
                                              int idx,
                                              const char *name,
                                              filter_add_t addfunc,
                                              const char *type)
{
    modperl_config_dir_t *dcfg =
        modperl_config_dir_get_defaults(c->base_server);
    MpAV *av;

    if ((av = dcfg->handlers_per_dir[idx])) {
        modperl_handler_t **handlers = (modperl_handler_t **)av->elts;
        int i;

        for (i=0; i<av->nelts; i++) {
            modperl_filter_ctx_t *ctx;

            if (!(handlers[i]->attrs & MP_FILTER_CONNECTION_HANDLER)) {
                MP_TRACE_f(MP_FUNC,
                           "%s is not an FilterConnection handler\n",
                           handlers[i]->name);
                continue;
            }

            ctx = (modperl_filter_ctx_t *)apr_pcalloc(c->pool, sizeof(*ctx));
            ctx->handler = handlers[i];
            addfunc(name, (void*)ctx, NULL, c);
        }

        return OK;
    }

    MP_TRACE_h(MP_FUNC, "no %s handlers configured (connection)\n", type);

    return DECLINED;
}

static int modperl_filter_register_request(request_rec *r,
                                           int idx,
                                           const char *name,
                                           filter_add_t addfunc,
                                           const char *type,
                                           ap_filter_t *filters)
{
    MP_dDCFG;
    MpAV *av;

    if ((av = dcfg->handlers_per_dir[idx])) {
        modperl_handler_t **handlers = (modperl_handler_t **)av->elts;
        int i;

        for (i=0; i<av->nelts; i++) {
            modperl_filter_ctx_t *ctx;
            int registered = 0;
            ap_filter_t *f = filters;

            while (f) {
                const char *fname = f->frec->name;

                if (*fname == 'M' && strEQ(fname, name)) {
                    modperl_handler_t *ctx_handler = 
                        ((modperl_filter_ctx_t *)f->ctx)->handler;

                    if (modperl_handler_equal(ctx_handler, handlers[i])) {
                        /* skip if modperl_filter_register_connection
                         * already registered this handler
                         * XXX: set a flag in the modperl_handler_t instead
                         */
                        registered = 1;
                        break;
                    }
                }

                f = f->next;
            }

            if (registered) {
                MP_TRACE_f(MP_FUNC,
                        "%s %s already registered\n",
                        handlers[i]->name, type);
                continue;
            }

            ctx = (modperl_filter_ctx_t *)apr_pcalloc(r->pool, sizeof(*ctx));
            ctx->handler = handlers[i];
            addfunc(name, (void*)ctx, r, r->connection);
        }

        return OK;
    }

    MP_TRACE_h(MP_FUNC, "no %s handlers configured (%s)\n",
               type, r->uri);

    return DECLINED;
}

void modperl_output_filter_register_connection(conn_rec *c)
{
    modperl_filter_register_connection(c,
                                       MP_OUTPUT_FILTER_HANDLER,
                                       MODPERL_OUTPUT_FILTER_NAME,
                                       ap_add_output_filter,
                                       "OutputFilter");
}

void modperl_output_filter_register_request(request_rec *r)
{
    modperl_filter_register_request(r,
                                    MP_OUTPUT_FILTER_HANDLER,
                                    MODPERL_OUTPUT_FILTER_NAME,
                                    ap_add_output_filter,
                                    "OutputFilter",
                                    r->connection->output_filters);
}

void modperl_input_filter_register_connection(conn_rec *c)
{
    modperl_filter_register_connection(c,
                                       MP_INPUT_FILTER_HANDLER,
                                       MODPERL_INPUT_FILTER_NAME,
                                       ap_add_input_filter,
                                       "InputFilter");
}

void modperl_input_filter_register_request(request_rec *r)
{
    modperl_filter_register_request(r,
                                    MP_INPUT_FILTER_HANDLER,
                                    MODPERL_INPUT_FILTER_NAME,
                                    ap_add_input_filter,
                                    "InputFilter",
                                    r->connection->input_filters);
}

void modperl_brigade_dump(apr_bucket_brigade *bb, FILE *fp)
{
    apr_bucket *bucket;
    int i = 0;
#ifndef WIN32
    if (fp == NULL) {
        fp = stderr;
    }

    fprintf(fp, "dump of brigade 0x%lx\n",
            (unsigned long)bb);

    APR_BRIGADE_FOREACH(bucket, bb) {
        fprintf(fp, "   %d: bucket=%s(0x%lx), length=%ld, data=0x%lx\n",
                i, bucket->type->name,
                (unsigned long)bucket,
                (long)bucket->length,
                (unsigned long)bucket->data);
        i++;
    }
#endif
}
