#include "mod_perl.h"

/* helper funcs */

#define MP_FILTER_NAME_FORMAT "   %s\n\n\t"

#define MP_FILTER_NAME(f) \
    ((modperl_filter_ctx_t *)f->ctx)->handler->name

#define MP_FILTER_TYPE(filter) \
    ((modperl_filter_ctx_t *)filter->f->ctx)->handler->attrs & \
        MP_FILTER_CONNECTION_HANDLER  ? "connection" : "request"

#define MP_FILTER_MODE(filter) \
    (filter->mode == MP_INPUT_FILTER_MODE ? "input" : "output")

#define MP_FILTER_POOL(f) f->r ? f->r->pool : f->c->pool

/* this function is for tracing only, it's not optimized for performance */
static const char* next_filter_name(ap_filter_t *f)
{
    const char *name = f->frec->name;

    /* frec->name is always lowercased */ 
    if (!strcasecmp(name, MP_FILTER_CONNECTION_INPUT_NAME)  ||
        !strcasecmp(name, MP_FILTER_CONNECTION_OUTPUT_NAME) ||
        !strcasecmp(name, MP_FILTER_REQUEST_INPUT_NAME)     ||
        !strcasecmp(name, MP_FILTER_REQUEST_OUTPUT_NAME) ) {
        return ((modperl_filter_ctx_t *)f->ctx)->handler->name;
    }
    else {
        return name;
    }
}

MP_INLINE static apr_status_t send_input_eos(modperl_filter_t *filter)
{
    apr_bucket_alloc_t *ba = filter->f->c->bucket_alloc;
    apr_bucket *b = apr_bucket_eos_create(ba);
    APR_BRIGADE_INSERT_TAIL(filter->bb_out, b);
    ((modperl_filter_ctx_t *)filter->f->ctx)->sent_eos = 1;
    return APR_SUCCESS;
}

MP_INLINE static apr_status_t send_input_flush(modperl_filter_t *filter)
{
    apr_bucket_alloc_t *ba = filter->f->c->bucket_alloc;
    apr_bucket *b = apr_bucket_flush_create(ba);
    APR_BRIGADE_INSERT_TAIL(filter->bb_out, b);
    return APR_SUCCESS;
}

MP_INLINE static apr_status_t send_output_eos(ap_filter_t *f)
{
    apr_bucket_alloc_t *ba = f->c->bucket_alloc;
    apr_bucket_brigade *bb = apr_brigade_create(MP_FILTER_POOL(f),
                                                ba);
    apr_bucket *b = apr_bucket_eos_create(ba);
    APR_BRIGADE_INSERT_TAIL(bb, b);
    ((modperl_filter_ctx_t *)f->ctx)->sent_eos = 1;
    MP_TRACE_f(MP_FUNC, MP_FILTER_NAME_FORMAT
               "write out: EOS bucket in separate bb\n", MP_FILTER_NAME(f));
    return ap_pass_brigade(f->next, bb);
}

MP_INLINE static apr_status_t send_output_flush(ap_filter_t *f)
{
    apr_bucket_alloc_t *ba = f->c->bucket_alloc;
    apr_bucket_brigade *bb = apr_brigade_create(MP_FILTER_POOL(f),
                                                ba);
    apr_bucket *b = apr_bucket_flush_create(ba);
    APR_BRIGADE_INSERT_TAIL(bb, b);
    MP_TRACE_f(MP_FUNC, MP_FILTER_NAME_FORMAT
               "write out: FLUSH bucket in separate bb\n", MP_FILTER_NAME(f));
    return ap_pass_brigade(f, bb);
}

/* simple buffer api */

MP_INLINE apr_status_t modperl_wbucket_pass(modperl_wbucket_t *wb,
                                            const char *buf, apr_size_t len,
                                            int add_flush_bucket)
{
    apr_bucket_alloc_t *ba = (*wb->filters)->c->bucket_alloc;
    apr_bucket_brigade *bb;
    apr_bucket *bucket;
    const char *work_buf = buf;

    if (wb->header_parse) {
        request_rec *r = wb->r;
        const char *bodytext = NULL;
        int status;
        /*
         * since wb->outbuf is persistent between requests, if the
         * current response is shorter than the size of wb->outbuf
         * it may include data from the previous request at the
         * end. When this function receives a pointer to
         * wb->outbuf as 'buf', modperl_cgi_header_parse may
         * return that irrelevant data as part of 'bodytext'. So
         * to avoid this risk, we create a new buffer of size 'len'
         * XXX: if buf wasn't 'const char *buf' we could simply do
         * buf[len] = '\0'
         */
        /* MP_IOBUFSIZE is the size of wb->outbuf */
        if (buf == wb->outbuf && len < MP_IOBUFSIZE) {
            work_buf = (char *)apr_pcalloc(wb->pool, sizeof(char*)*len);
            memcpy((void*)work_buf, buf, len);
        }
        status = modperl_cgi_header_parse(r, (char *)work_buf, &bodytext);

        wb->header_parse = 0; /* only once per-request */

        if (status == HTTP_MOVED_TEMPORARILY) {
            return APR_SUCCESS; /* XXX: HTTP_MOVED_TEMPORARILY ? */
        }
        else if (status != OK) {
            ap_log_error(APLOG_MARK, APLOG_WARNING,
                         0, r->server, "%s did not send an HTTP header",
                         r->uri);
            /* XXX: bodytext == NULL here */
            return status;
        }
        else if (!bodytext) {
            return APR_SUCCESS;
        }

        len -= (bodytext - work_buf);
        work_buf = bodytext;
    }

    bb = apr_brigade_create(wb->pool, ba);
    bucket = apr_bucket_transient_create(work_buf, len, ba);
    APR_BRIGADE_INSERT_TAIL(bb, bucket);

    if (add_flush_bucket) {
        /* append the flush bucket rather then calling ap_rflush, to
         * prevent a creation of yet another bb, which will cause an
         * extra call for each filter in the chain */
        apr_bucket *bucket = apr_bucket_flush_create(ba);
        APR_BRIGADE_INSERT_TAIL(bb, bucket);
    }
        
    MP_TRACE_f(MP_FUNC, "\n\n\twrite out: %d bytes\n"
               "\t\tfrom %s\n\t\tto %s filter handler\n",
               len, 
               (wb->r && wb->filters == &wb->r->output_filters)
                   ? "response handler" : "current filter handler",
               next_filter_name(*(wb->filters)));

    return ap_pass_brigade(*(wb->filters), bb);
}

/* if add_flush_bucket is TRUE
 *  and there is data to flush,
 *       a flush bucket is added to the tail of bb with data
 * otherwise
 *       a flush bucket is sent in its own bb
 */
MP_INLINE apr_status_t modperl_wbucket_flush(modperl_wbucket_t *wb,
                                             int add_flush_bucket)
{
    apr_status_t rv = APR_SUCCESS;

    if (wb->outcnt) {
        rv = modperl_wbucket_pass(wb, wb->outbuf, wb->outcnt,
                                  add_flush_bucket);
        wb->outcnt = 0;
    }
    else if (add_flush_bucket) {
        rv = send_output_flush(*(wb->filters));
    }
    
    return rv;
}

MP_INLINE apr_status_t modperl_wbucket_write(pTHX_ modperl_wbucket_t *wb,
                                             const char *buf,
                                             apr_size_t *wlen)
{
    apr_size_t len = *wlen;
    *wlen = 0;

    MP_TRACE_f(MP_FUNC, "\n\n\tbuffer out: %d bytes\n", len);

    if ((len + wb->outcnt) > sizeof(wb->outbuf)) {
        apr_status_t rv;
        if ((rv = modperl_wbucket_flush(wb, FALSE)) != APR_SUCCESS) {
            return rv;
        }
    }

    if (len >= sizeof(wb->outbuf)) {
        *wlen = len;
        return modperl_wbucket_pass(wb, buf, len, FALSE);
    }
    else {
        memcpy(&wb->outbuf[wb->outcnt], buf, len);
        wb->outcnt += len;
        *wlen = len;
        return APR_SUCCESS;
    }
}

/* generic filter routines */

modperl_filter_t *modperl_filter_new(ap_filter_t *f,
                                     apr_bucket_brigade *bb,
                                     modperl_filter_mode_e mode,
                                     ap_input_mode_t input_mode,
                                     apr_read_type_e block,
                                     apr_off_t readbytes)
{
    apr_pool_t *p = MP_FILTER_POOL(f);
    modperl_filter_t *filter = apr_pcalloc(p, sizeof(*filter));

    filter->mode = mode;
    filter->f = f;
    filter->pool = p;
    filter->wbucket.pool = p;
    filter->wbucket.filters = &f->next;
    filter->wbucket.outcnt = 0;

    if (mode == MP_INPUT_FILTER_MODE) {
        filter->bb_in  = NULL;
        filter->bb_out = bb;
        filter->input_mode = input_mode;
        filter->block = block;
        filter->readbytes = readbytes;
    }
    else {
        filter->bb_in  = bb;
        filter->bb_out = NULL;
    }

    MP_TRACE_f(MP_FUNC, MP_FILTER_NAME_FORMAT
               "new: %s %s filter (0x%lx)\n",
               MP_FILTER_NAME(f),
               MP_FILTER_TYPE(filter), MP_FILTER_MODE(filter),
               (unsigned long)filter);

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

/* eval "package Foo; \&init_handler" */
int modperl_filter_resolve_init_handler(pTHX_ modperl_handler_t *handler,
                                        apr_pool_t *p)
{
    char *init_handler_pv_code;
    char *package_name;
    CV *cv;
    MAGIC *mg;
    
    if (handler->mgv_cv) {
        GV *gv;
        if ((gv = modperl_mgv_lookup(aTHX_ handler->mgv_cv))) {
            cv = modperl_mgv_cv(gv);
            package_name = modperl_mgv_as_string(aTHX_ handler->mgv_cv, p, 1);
            /* fprintf(stderr, "PACKAGE: %s\n", package_name ); */
        }
    }

    if (cv && SvMAGICAL(cv)) {
        mg = mg_find((SV*)(cv), '~');
        init_handler_pv_code = mg ? mg->mg_ptr : NULL;
    }
    else {
        /* XXX: should we complain in such a case? */
        return 0;
    }
    
    if (init_handler_pv_code) {
        /* eval the code in the parent handler's package's context */
        char *code = apr_pstrcat(p, "package ", package_name, ";",
                                 init_handler_pv_code, NULL);
        SV *sv = eval_pv(code, TRUE);
        char *init_handler_name;

        /* fprintf(stderr, "code: %s\n", code); */
        
        if ((init_handler_name = modperl_mgv_name_from_sv(aTHX_ p, sv))) {
            modperl_handler_t *init_handler =
                modperl_handler_new(p, apr_pstrdup(p, init_handler_name));

            MP_TRACE_h(MP_FUNC, "found init handler %s\n",
                       init_handler->name);

            if (! init_handler->attrs & MP_FILTER_INIT_HANDLER) {
                Perl_croak(aTHX_ "handler %s doesn't have "
                           "the FilterInitHandler attribute set",
                           init_handler->name);
            }
            
            handler->next = init_handler;
            return 1;
        }
        else {
            Perl_croak(aTHX_ "failed to eval code: %s", code);
            
        }
    }

    return 1;
}

static int modperl_run_filter_init(ap_filter_t *f,
                                   modperl_handler_t *handler) 
{
    AV *args = Nullav;
    int status;

    request_rec *r = f->r;
    conn_rec    *c = f->c;
    server_rec  *s = r ? r->server : c->base_server;
    apr_pool_t  *p = r ? r->pool : c->pool;

    MP_dINTERP_SELECT(r, c, s);    

    MP_TRACE_h(MP_FUNC, "running filter init handler %s\n", handler->name);
            
    modperl_handler_make_args(aTHX_ &args,
                              "Apache::Filter", f,
                              NULL);

    /* XXX: do we need it? */
    /* modperl_filter_mg_set(aTHX_ AvARRAY(args)[0], filter); */

    if ((status = modperl_callback(aTHX_ handler, p, r, s, args)) != OK) {
        status = modperl_errsv(aTHX_ status, r, s);
    }

    SvREFCNT_dec((SV*)args);

    MP_TRACE_f(MP_FUNC, MP_FILTER_NAME_FORMAT
               "return: %d\n", handler->name, status);
    
    return status;  
}


int modperl_run_filter(modperl_filter_t *filter)
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
                              "APR::Brigade",
                              (filter->mode == MP_INPUT_FILTER_MODE
                               ? filter->bb_out
                               : filter->bb_in),
                              NULL);

    modperl_filter_mg_set(aTHX_ AvARRAY(args)[0], filter);

    if (filter->mode == MP_INPUT_FILTER_MODE) {
        av_push(args, newSViv(filter->input_mode));
        av_push(args, newSViv(filter->block));
        av_push(args, newSViv(filter->readbytes));
    }

    if ((status = modperl_callback(aTHX_ handler, p, r, s, args)) != OK) {
        status = modperl_errsv(aTHX_ status, r, s);
    }

    SvREFCNT_dec((SV*)args);

    /* when the streaming filter is invoked it should be able to send
     * extra data, after the read in a while() loop is finished.
     * Therefore we need to postpone propogating the EOS bucket, up
     * until the filter handler is returned and only then send the EOS
     * bucket if the stream had one.
     */
    if (filter->seen_eos) {
        filter->eos = 1;
        filter->seen_eos = 0;
    }

    if (filter->mode == MP_INPUT_FILTER_MODE) {
        if (filter->bb_in) {
            /* in the streaming mode filter->bb_in is populated on the
             * first modperl_input_filter_read, so it must be
             * destroyed at the end of the filter invocation
             */
            apr_brigade_destroy(filter->bb_in);
            filter->bb_in = NULL;
        }
        MP_FAILURE_CROAK(modperl_input_filter_flush(filter));
    }
    else {
        MP_FAILURE_CROAK(modperl_output_filter_flush(filter));
    }

    MP_TRACE_f(MP_FUNC, MP_FILTER_NAME_FORMAT
               "return: %d\n", handler->name, status);
    
    return status;
}


/* unrolled APR_BRIGADE_FOREACH loop */

#define MP_FILTER_EMPTY(filter) \
APR_BRIGADE_EMPTY(filter->bb_in)

#define MP_FILTER_SENTINEL(filter) \
APR_BRIGADE_SENTINEL(filter->bb_in)

#define MP_FILTER_FIRST(filter) \
APR_BRIGADE_FIRST(filter->bb_in)

#define MP_FILTER_NEXT(filter) \
APR_BUCKET_NEXT(filter->bucket)

#define MP_FILTER_IS_EOS(filter) \
APR_BUCKET_IS_EOS(filter->bucket)

#define MP_FILTER_IS_FLUSH(filter) \
APR_BUCKET_IS_FLUSH(filter->bucket)

MP_INLINE static int get_bucket(modperl_filter_t *filter)
{
    if (!filter->bb_in || MP_FILTER_EMPTY(filter)) {
        MP_TRACE_f(MP_FUNC, MP_FILTER_NAME_FORMAT
                   "read in: bucket brigade is empty\n",
                   MP_FILTER_NAME(filter->f));
        return 0;
    }
    
    if (!filter->bucket) {
        filter->bucket = MP_FILTER_FIRST(filter);
    }
    else if (filter->bucket != MP_FILTER_SENTINEL(filter)) {
        filter->bucket = MP_FILTER_NEXT(filter);
    }

    if (filter->bucket == MP_FILTER_SENTINEL(filter)) {
        filter->bucket = NULL;
        /* can't destroy bb_in since the next read will need a brigade
         * to try to read from */
        apr_brigade_cleanup(filter->bb_in);
        return 0;
    }
    
    if (MP_FILTER_IS_EOS(filter)) {
        MP_TRACE_f(MP_FUNC, MP_FILTER_NAME_FORMAT
                   "read in: EOS bucket\n",
                   MP_FILTER_NAME(filter->f));

        filter->seen_eos = 1;
        /* there should be only one EOS sent, modperl_filter_read will
         * not come here, since filter->seen_eos is set
         */
        return 0;
    }
    else if (MP_FILTER_IS_FLUSH(filter)) {
        MP_TRACE_f(MP_FUNC, MP_FILTER_NAME_FORMAT
                   "read in: FLUSH bucket\n",
                   MP_FILTER_NAME(filter->f));
        filter->flush = 1;
        return 0;
    }
    else {
        return 1;
    }
}


MP_INLINE static apr_size_t modperl_filter_read(pTHX_
                                                modperl_filter_t *filter,
                                                SV *buffer,
                                                apr_size_t wanted)
{
    int num_buckets = 0;
    apr_size_t len = 0;
    
    (void)SvUPGRADE(buffer, SVt_PV);
    SvPOK_only(buffer);
    SvCUR(buffer) = 0;

    /* sometimes the EOS bucket arrives in the same brigade with other
     * buckets, so that particular read() will not return 0 and will
     * be called again if called in the while ($filter->read(...))
     * loop. In that case we return 0.
     */
    if (filter->seen_eos) {
        return 0;
    }
    
    /*modperl_brigade_dump(filter->bb_in, stderr);*/

    MP_TRACE_f(MP_FUNC, MP_FILTER_NAME_FORMAT
               "wanted: %d bytes\n",
               MP_FILTER_NAME(filter->f),
               wanted);

    if (filter->remaining) {
        if (filter->remaining >= wanted) {
            MP_TRACE_f(MP_FUNC, MP_FILTER_NAME_FORMAT
                       "eating and returning %d of "
                       "remaining %d leftover bytes\n",
                       MP_FILTER_NAME(filter->f),
                       wanted, filter->remaining);
            sv_catpvn(buffer, filter->leftover, wanted);
            filter->leftover += wanted;
            filter->remaining -= wanted;
            return wanted;
        }
        else {
            MP_TRACE_f(MP_FUNC, MP_FILTER_NAME_FORMAT
                       "eating remaining %d leftover bytes\n",
                       MP_FILTER_NAME(filter->f),
                       filter->remaining);
            sv_catpvn(buffer, filter->leftover, filter->remaining);
            len = filter->remaining;
            filter->remaining = 0;
            filter->leftover = NULL;
        }
    }

    while (1) {
        const char *buf;
        apr_size_t buf_len;

        if (!get_bucket(filter)) {
            break;
        }

        num_buckets++;

        filter->rc = apr_bucket_read(filter->bucket, &buf, &buf_len, 0);

        if (filter->rc == APR_SUCCESS) {
            MP_TRACE_f(MP_FUNC,
                       MP_FILTER_NAME_FORMAT
                       "read in: %s bucket with %d bytes (0x%lx)\n",
                       MP_FILTER_NAME(filter->f),
                       filter->bucket->type->name,
                       buf_len,
                       (unsigned long)filter->bucket);
        }
        else {
            MP_TRACE_f(MP_FUNC,
                       MP_FILTER_NAME_FORMAT
                       "read in: apr_bucket_read error: %s\n",
                       MP_FILTER_NAME(filter->f),
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

    MP_TRACE_f(MP_FUNC,
               MP_FILTER_NAME_FORMAT
               "return: %d bytes from %d bucket%s (%d bytes leftover)\n",
               MP_FILTER_NAME(filter->f),
               len, num_buckets, ((num_buckets == 1) ? "" : "s"),
               filter->remaining);

    return len;
}

MP_INLINE apr_size_t modperl_input_filter_read(pTHX_
                                               modperl_filter_t *filter,
                                               SV *buffer,
                                               apr_size_t wanted)
{
    apr_size_t len = 0;

    if (!filter->bb_in) {
        /* This should be read only once per handler invocation! */
        filter->bb_in = apr_brigade_create(filter->pool,
                                           filter->f->c->bucket_alloc);
        ap_get_brigade(filter->f->next, filter->bb_in,
                       filter->input_mode, filter->block, filter->readbytes);
        MP_TRACE_f(MP_FUNC, MP_FILTER_NAME_FORMAT
                   "retrieving bb: 0x%lx\n",
                   MP_FILTER_NAME(filter->f),
                   (unsigned long)(filter->bb_in));
    }

    len = modperl_filter_read(aTHX_ filter, buffer, wanted);

/*     if (APR_BRIGADE_EMPTY(filter->bb_in)) { */
/*         apr_brigade_destroy(filter->bb_in); */
/*         filter->bb_in = NULL; */
/*     } */

    if (filter->flush && len == 0) {
        /* if len > 0 then $filter->write will flush */
        modperl_input_filter_flush(filter);
    }

    return len;
}


MP_INLINE apr_size_t modperl_output_filter_read(pTHX_
                                                modperl_filter_t *filter,
                                                SV *buffer,
                                                apr_size_t wanted)
{
    apr_size_t len = 0;
    len = modperl_filter_read(aTHX_ filter, buffer, wanted);
    
    if (filter->flush && len == 0) {
        /* if len > 0 then $filter->write will flush */
        MP_FAILURE_CROAK(modperl_output_filter_flush(filter));
    }

    return len;
}


MP_INLINE apr_status_t modperl_input_filter_flush(modperl_filter_t *filter)
{
    if (((modperl_filter_ctx_t *)filter->f->ctx)->sent_eos) {
        /* no data should be sent after EOS has been sent */
        return filter->rc;
    }
    
    if (filter->eos || filter->flush) {
        MP_TRACE_f(MP_FUNC, MP_FILTER_NAME_FORMAT
                   "write out: %s bucket\n",
                   MP_FILTER_NAME(filter->f),
                   filter->eos ? "EOS" : "FLUSH");
        filter->rc = filter->eos ?
            send_input_eos(filter) : send_input_flush(filter);
        /* modperl_brigade_dump(filter->bb_out, stderr); */
        filter->flush = filter->eos = 0;
    }
    
    return filter->rc;
}

MP_INLINE apr_status_t modperl_output_filter_flush(modperl_filter_t *filter)
{
    int add_flush_bucket = FALSE;
    
    if (((modperl_filter_ctx_t *)filter->f->ctx)->sent_eos) {
        /* no data should be sent after EOS has been sent */
        return filter->rc;
    }

    if (filter->flush) {
        add_flush_bucket = TRUE;
        filter->flush = 0;
    }

    filter->rc = modperl_wbucket_flush(&filter->wbucket, add_flush_bucket);
    if (filter->rc != APR_SUCCESS) {
        return filter->rc;
    }

    if (filter->eos) {
        filter->rc = send_output_eos(filter->f);
        if (filter->bb_in) {
            apr_brigade_destroy(filter->bb_in);
            filter->bb_in = NULL;
        }
        filter->eos = 0;
    }

    return filter->rc;
}

MP_INLINE apr_status_t modperl_input_filter_write(pTHX_
                                                  modperl_filter_t *filter,
                                                  const char *buf,
                                                  apr_size_t *len)
{
    apr_bucket_alloc_t *ba = filter->f->c->bucket_alloc;
    char *copy = apr_pstrndup(filter->pool, buf, *len);
    apr_bucket *bucket = apr_bucket_transient_create(copy, *len, ba);
    /* MP_TRACE_f(MP_FUNC, "writing %d bytes: %s\n", *len, copy); */
    MP_TRACE_f(MP_FUNC, MP_FILTER_NAME_FORMAT
               "write out: %d bytes:\n",
               MP_FILTER_NAME(filter->f),
               *len);
    APR_BRIGADE_INSERT_TAIL(filter->bb_out, bucket);
    /* modperl_brigade_dump(filter->bb_out, stderr); */
    return APR_SUCCESS;
}

MP_INLINE apr_status_t modperl_output_filter_write(pTHX_
                                                   modperl_filter_t *filter,
                                                   const char *buf,
                                                   apr_size_t *len)
{
    return modperl_wbucket_write(aTHX_ &filter->wbucket, buf, len);
}

apr_status_t modperl_output_filter_handler(ap_filter_t *f,
                                           apr_bucket_brigade *bb)
{
    modperl_filter_t *filter;
    int status;

    if (((modperl_filter_ctx_t *)f->ctx)->sent_eos) {
        MP_TRACE_f(MP_FUNC,
                   MP_FILTER_NAME_FORMAT
                   "write_out: EOS was already sent, "
                   "passing through the brigade\n",
                   MP_FILTER_NAME(f));
        return ap_pass_brigade(f->next, bb);
    }
    else {
        filter = modperl_filter_new(f, bb, MP_OUTPUT_FILTER_MODE,
                                    0, 0, 0);
        status = modperl_run_filter(filter);
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
                                          ap_input_mode_t input_mode,
                                          apr_read_type_e block,
                                          apr_off_t readbytes)
{
    modperl_filter_t *filter;
    int status;

    if (((modperl_filter_ctx_t *)f->ctx)->sent_eos) {
        MP_TRACE_f(MP_FUNC,
                   MP_FILTER_NAME_FORMAT
                   "write out: EOS was already sent, "
                   "passing through the brigade\n",
                   MP_FILTER_NAME(f));
        return ap_get_brigade(f->next, bb, input_mode, block, readbytes);
    }
    else {
        filter = modperl_filter_new(f, bb, MP_INPUT_FILTER_MODE,
                                    input_mode, block, readbytes);
        status = modperl_run_filter(filter);
    }
    
    switch (status) {
      case OK:
        return APR_SUCCESS;
      case DECLINED:
        return ap_get_brigade(f->next, bb, input_mode, block, readbytes);
      default:
        return status; /*XXX*/
    }
}

static int modperl_filter_add_connection(conn_rec *c,
                                         int idx,
                                         const char *name,
                                         modperl_filter_add_t addfunc,
                                         const char *type)
{
    modperl_config_dir_t *dcfg =
        modperl_config_dir_get_defaults(c->base_server);
    MpAV *av;

    if ((av = dcfg->handlers_per_dir[idx])) {
        modperl_handler_t **handlers = (modperl_handler_t **)av->elts;
        int i;
        ap_filter_t *f;

        for (i=0; i<av->nelts; i++) {
            modperl_filter_ctx_t *ctx;

            if ((handlers[i]->attrs & MP_FILTER_HTTPD_HANDLER)) {
                addfunc(handlers[i]->name, NULL, NULL, c);
                MP_TRACE_f(MP_FUNC,
                           "a non-mod_perl %s handler %s configured (connection)\n",
                           type, handlers[i]->name);
                continue;
            }
            
            if (!(handlers[i]->attrs & MP_FILTER_CONNECTION_HANDLER)) {
                MP_TRACE_f(MP_FUNC,
                           "%s is not a FilterConnection handler\n",
                           handlers[i]->name);
                continue;
            }

            ctx = (modperl_filter_ctx_t *)apr_pcalloc(c->pool, sizeof(*ctx));
            ctx->handler = handlers[i];

            f = addfunc(name, (void*)ctx, NULL, c);

            if (handlers[i]->attrs & MP_FILTER_HAS_INIT_HANDLER &&
                handlers[i]->next) {
                int status = modperl_run_filter_init(f, handlers[i]->next);
                if (status != OK) {
                    return status;
                }
            }
            
            MP_TRACE_h(MP_FUNC, "%s handler %s configured (connection)\n",
                       type, handlers[i]->name);
        }

        return OK;
    }

    MP_TRACE_h(MP_FUNC, "no %s handlers configured (connection)\n", type);

    return DECLINED;
}

static int modperl_filter_add_request(request_rec *r,
                                      int idx,
                                      const char *name,
                                      modperl_filter_add_t addfunc,
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
            ap_filter_t *f;

            if ((handlers[i]->attrs & MP_FILTER_HTTPD_HANDLER)) {
                addfunc(handlers[i]->name, NULL, r, r->connection);
                MP_TRACE_f(MP_FUNC,
                           "a non-mod_perl %s handler %s configured (%s)\n",
                           type, handlers[i]->name, r->uri);
                continue;
            }

            f = filters;
            while (f) {
                const char *fname = f->frec->name;

                /* XXX: I think this won't work as f->frec->name gets
                 * lowercased when added to the chain */
                if (*fname == 'M' && strEQ(fname, name)) {
                    modperl_handler_t *ctx_handler = 
                        ((modperl_filter_ctx_t *)f->ctx)->handler;

                    if (modperl_handler_equal(ctx_handler, handlers[i])) {
                        /* skip if modperl_filter_add_connection
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

            f = addfunc(name, (void*)ctx, r, r->connection);

            if (handlers[i]->attrs & MP_FILTER_HAS_INIT_HANDLER &&
                handlers[i]->next) {
                int status = modperl_run_filter_init(f, handlers[i]->next);
                if (status != OK) {
                    return status;
                }
            }
            
            MP_TRACE_h(MP_FUNC, "%s handler %s configured (%s)\n",
                       type, handlers[i]->name, r->uri);
        }

        return OK;
    }

    MP_TRACE_h(MP_FUNC, "no %s handlers configured (%s)\n",
               type, r->uri);

    return DECLINED;
}

void modperl_output_filter_add_connection(conn_rec *c)
{
    modperl_filter_add_connection(c,
                                  MP_OUTPUT_FILTER_HANDLER,
                                  MP_FILTER_CONNECTION_OUTPUT_NAME,
                                  ap_add_output_filter,
                                  "OutputFilter");
}

void modperl_output_filter_add_request(request_rec *r)
{
    modperl_filter_add_request(r,
                               MP_OUTPUT_FILTER_HANDLER,
                               MP_FILTER_REQUEST_OUTPUT_NAME,
                               ap_add_output_filter,
                               "OutputFilter",
                               r->connection->output_filters);
}

void modperl_input_filter_add_connection(conn_rec *c)
{
    modperl_filter_add_connection(c,
                                  MP_INPUT_FILTER_HANDLER,
                                  MP_FILTER_CONNECTION_INPUT_NAME,
                                  ap_add_input_filter,
                                  "InputFilter");
}

void modperl_input_filter_add_request(request_rec *r)
{
    modperl_filter_add_request(r,
                               MP_INPUT_FILTER_HANDLER,
                               MP_FILTER_REQUEST_INPUT_NAME,
                               ap_add_input_filter,
                               "InputFilter",
                               r->connection->input_filters);
}

void modperl_filter_runtime_add(pTHX_ request_rec *r, conn_rec *c,
                                const char *name,
                                modperl_filter_add_t addfunc,
                                SV *callback, const char *type)
{
    apr_pool_t *pool = r ? r->pool : c->pool;
    char *handler_name;

    if ((handler_name = modperl_mgv_name_from_sv(aTHX_ pool, callback))) {
        ap_filter_t *f;
        modperl_handler_t *handler =
            modperl_handler_new(pool, apr_pstrdup(pool, handler_name));
        modperl_filter_ctx_t *ctx =
            (modperl_filter_ctx_t *)apr_pcalloc(pool, sizeof(*ctx));

        ctx->handler = handler;
        f = addfunc(name, (void*)ctx, r, c);

        /* has to resolve early so we can check for init functions */ 
        if (!modperl_mgv_resolve(aTHX_ handler, pool, handler->name, TRUE)) {
            Perl_croak(aTHX_ "unable to resolve handler %s\n", handler->name);
        }

        if (handler->attrs & MP_FILTER_HAS_INIT_HANDLER && handler->next) {
            int status = modperl_run_filter_init(f, handler->next);
            if (status != OK) {
                /* XXX */
            }
        }
        
        MP_TRACE_h(MP_FUNC, "%s handler %s configured (connection)\n",
                   type, name);

        return;
    }

    Perl_croak(aTHX_ "unable to resolve handler 0x%lx\n",
               (unsigned long)callback);
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
        /* fprintf(fp, "       : %s\n", (char *)bucket->data); */
        
        i++;
    }
#endif
}
