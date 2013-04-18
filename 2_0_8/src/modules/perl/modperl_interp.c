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
 * XXX: this is not the most efficent interpreter pool implementation
 * but it will do for proof-of-concept
 */

#ifdef USE_ITHREADS

static const char *MP_interp_scope_desc[] = {
    "undef", "handler", "subrequest", "request", "connection",
};

const char *modperl_interp_scope_desc(modperl_interp_scope_e scope)
{
    return MP_interp_scope_desc[scope];
}

void modperl_interp_clone_init(modperl_interp_t *interp)
{
    dTHXa(interp->perl);

    MpInterpCLONED_On(interp);

    PERL_SET_CONTEXT(aTHX);

    /* XXX: hack for bug fixed in 5.6.1 */
    if (PL_scopestack_ix == 0) {
        ENTER;
    }

    /* clear @DynaLoader::dl_librefs so we only dlclose() those
     * which are opened by the clone
     */
    modperl_xs_dl_handles_clear(aTHX);
}

modperl_interp_t *modperl_interp_new(modperl_interp_pool_t *mip,
                                     PerlInterpreter *perl)
{
    UV clone_flags = CLONEf_KEEP_PTR_TABLE;
    modperl_interp_t *interp =
        (modperl_interp_t *)malloc(sizeof(*interp));

    memset(interp, '\0', sizeof(*interp));

    interp->mip = mip;
    interp->refcnt = 0; /* for use by APR::Pool->cleanup_register */

    if (perl) {
#ifdef MP_USE_GTOP
        MP_dSCFG(mip->server);
        MP_TRACE_m_do(
            modperl_gtop_do_proc_mem_before(MP_FUNC, "perl_clone");
        );
#endif

#if defined(WIN32) && defined(CLONEf_CLONE_HOST)
        clone_flags |= CLONEf_CLONE_HOST;
#endif

        PERL_SET_CONTEXT(perl);

        interp->perl = perl_clone(perl, clone_flags);

#if MP_PERL_VERSION(5, 8, 0) && \
    defined(USE_REENTRANT_API) && defined(HAS_CRYPT_R) && defined(__GLIBC__)
        {
            dTHXa(interp->perl);
            /* workaround 5.8.0 bug */
            PL_reentrant_buffer->_crypt_struct.current_saltbits = 0;
        }
#endif

        {
            PTR_TBL_t *source = modperl_module_config_table_get(perl, FALSE);
            if (source) {
                PTR_TBL_t *table = modperl_svptr_table_clone(interp->perl,
                                                             perl,
                                                             source);

                modperl_module_config_table_set(interp->perl, table);
            }
        }

        /*
         * we keep the PL_ptr_table past perl_clone so it can be used
         * within modperl_svptr_table_clone.
         */
        if ((clone_flags & CLONEf_KEEP_PTR_TABLE)) {
            dTHXa(interp->perl);
            ptr_table_free(PL_ptr_table);
            PL_ptr_table = NULL;
        }

        modperl_interp_clone_init(interp);

        PERL_SET_CONTEXT(perl);

#ifdef MP_USE_GTOP
        MP_TRACE_m_do(
            modperl_gtop_do_proc_mem_after(MP_FUNC, "perl_clone");
        );
#endif
    }

    MP_TRACE_i(MP_FUNC, "0x%lx / perl: 0x%lx / parent perl: 0x%lx",
               (unsigned long)interp, (unsigned long)interp->perl,
               (unsigned long)perl);

    return interp;
}

void modperl_interp_destroy(modperl_interp_t *interp)
{
    void **handles;
    dTHXa(interp->perl);

    PERL_SET_CONTEXT(interp->perl);

    MP_TRACE_i(MP_FUNC, "interp == 0x%lx / perl: 0x%lx",
               (unsigned long)interp, (unsigned long)interp->perl);

    if (MpInterpIN_USE(interp)) {
        MP_TRACE_i(MP_FUNC, "*error - still in use!*");
    }

    handles = modperl_xs_dl_handles_get(aTHX);

    modperl_perl_destruct(interp->perl);

    modperl_xs_dl_handles_close(handles);

    free(interp);
}

apr_status_t modperl_interp_cleanup(void *data)
{
    modperl_interp_destroy((modperl_interp_t *)data);
    return APR_SUCCESS;
}

modperl_interp_t *modperl_interp_get(server_rec *s)
{
    MP_dSCFG(s);
    modperl_interp_t *interp = NULL;
    modperl_interp_pool_t *mip = scfg->mip;
    modperl_list_t *head;

    head = modperl_tipool_pop(mip->tipool);
    interp = (modperl_interp_t *)head->data;

    MP_TRACE_i(MP_FUNC, "head == 0x%lx, parent == 0x%lx",
               (unsigned long)head, (unsigned long)mip->parent);

    MP_TRACE_i(MP_FUNC, "selected 0x%lx (perl==0x%lx)",
               (unsigned long)interp,
               (unsigned long)interp->perl);

#ifdef MP_TRACE
    interp->tid = MP_TIDF;
    MP_TRACE_i(MP_FUNC, "thread == 0x%lx", interp->tid);
#endif

    MpInterpIN_USE_On(interp);

    return interp;
}

apr_status_t modperl_interp_pool_destroy(void *data)
{
    modperl_interp_pool_t *mip = (modperl_interp_pool_t *)data;

    if (mip->tipool) {
        modperl_tipool_destroy(mip->tipool);
        mip->tipool = NULL;
    }

    if (MpInterpBASE(mip->parent)) {
        /* multiple mips might share the same parent
         * make sure its only destroyed once
         */
        MP_TRACE_i(MP_FUNC, "parent == 0x%lx",
                   (unsigned long)mip->parent);

        modperl_interp_destroy(mip->parent);
    }

    return APR_SUCCESS;
}

static void *interp_pool_grow(modperl_tipool_t *tipool, void *data)
{
    modperl_interp_pool_t *mip = (modperl_interp_pool_t *)data;
    MP_TRACE_i(MP_FUNC, "adding new interpreter to the pool");
    return (void *)modperl_interp_new(mip, mip->parent->perl);
}

static void interp_pool_shrink(modperl_tipool_t *tipool, void *data,
                               void *item)
{
    modperl_interp_destroy((modperl_interp_t *)item);
}

static void interp_pool_dump(modperl_tipool_t *tipool, void *data,
                             modperl_list_t *listp)
{
    while (listp) {
        modperl_interp_t *interp = (modperl_interp_t *)listp->data;
        MP_TRACE_i(MP_FUNC, "listp==0x%lx, interp==0x%lx, requests=%d",
                 (unsigned long)listp, (unsigned long)interp,
                 interp->num_requests);
        listp = listp->next;
    }
}

static modperl_tipool_vtbl_t interp_pool_func = {
    interp_pool_grow,
    interp_pool_grow,
    interp_pool_shrink,
    interp_pool_shrink,
    interp_pool_dump,
};

void modperl_interp_init(server_rec *s, apr_pool_t *p,
                         PerlInterpreter *perl)
{
    apr_pool_t *server_pool = modperl_server_pool();
    pTHX;
    MP_dSCFG(s);
    modperl_interp_pool_t *mip =
        (modperl_interp_pool_t *)apr_pcalloc(p, sizeof(*mip));

    MP_TRACE_i(MP_FUNC, "server=%s", modperl_server_desc(s, p));

    if (modperl_threaded_mpm()) {
        mip->tipool = modperl_tipool_new(p, scfg->interp_pool_cfg,
                                         &interp_pool_func, mip);
    }

    mip->server = s;
    mip->parent = modperl_interp_new(mip, NULL);
    aTHX = mip->parent->perl = perl;

    /* this happens post-config in mod_perl.c:modperl_init_clones() */
    /* modperl_tipool_init(tipool); */

    apr_pool_cleanup_register(server_pool, (void*)mip,
                              modperl_interp_pool_destroy,
                              apr_pool_cleanup_null);

    scfg->mip = mip;
}

apr_status_t modperl_interp_unselect(void *data)
{
    modperl_interp_t *interp = (modperl_interp_t *)data;
    modperl_interp_pool_t *mip = interp->mip;

    if (interp->refcnt != 0) {
        --interp->refcnt;
        MP_TRACE_i(MP_FUNC, "interp=0x%lx, refcnt=%d",
                   (unsigned long)interp, interp->refcnt);
        return APR_SUCCESS;
    }

    if (interp->request) {
        /* ithreads + a threaded mpm + PerlInterpScope handler */
        request_rec *r = interp->request;
        MP_dRCFG;
        modperl_config_request_cleanup(interp->perl, r);
        MpReqCLEANUP_REGISTERED_Off(rcfg);
    }

    MpInterpIN_USE_Off(interp);
    MpInterpPUTBACK_Off(interp);

    modperl_thx_interp_set(interp->perl, NULL);

    modperl_tipool_putback_data(mip->tipool, data, interp->num_requests);

    return APR_SUCCESS;
}

/* XXX:
 * interp is marked as in_use for the scope of the pool it is
 * stashed in.  this is done to avoid the tipool->tlock whenever
 * possible.  neither approach is ideal.
 */
#define MP_INTERP_KEY "MODPERL_INTERP"

#define get_interp(p) \
    (void)apr_pool_userdata_get((void **)&interp, MP_INTERP_KEY, p)

#define set_interp(p) \
     (void)apr_pool_userdata_set((void *)interp, MP_INTERP_KEY, \
                                 modperl_interp_unselect, \
                                 p)

modperl_interp_t *modperl_interp_pool_get(apr_pool_t *p)
{
    modperl_interp_t *interp = NULL;
    get_interp(p);
    return interp;
}

void modperl_interp_pool_set(apr_pool_t *p,
                             modperl_interp_t *interp,
                             int cleanup)
{
    /* same as get_interp but optional cleanup  */
    (void)apr_pool_userdata_set((void *)interp, MP_INTERP_KEY,
                                cleanup ? modperl_interp_unselect : NULL,
                                p);
}

/*
 * used in the case where we don't have a request_rec or conn_rec,
 * such as for directive handlers per-{dir,srv} create and merge.
 * "request time pool" is most likely a request_rec->pool.
 */
modperl_interp_t *modperl_interp_pool_select(apr_pool_t *p,
                                             server_rec *s)
{
    int is_startup = (p == s->process->pconf);
    MP_dSCFG(s);
    modperl_interp_t *interp = NULL;

    if (scfg && (is_startup || !modperl_threaded_mpm())) {
        MP_TRACE_i(MP_FUNC, "using parent interpreter at %s",
                   is_startup ? "startup" : "request time (non-threaded MPM)");

        if (!scfg->mip) {
            /* we get here if directive handlers are invoked
             * before server merge.
             */
            modperl_init_vhost(s, p, NULL);
        }

        interp = scfg->mip->parent;
    }
    else {
        if (!(interp = modperl_interp_pool_get(p))) {
            interp = modperl_interp_get(s);
            modperl_interp_pool_set(p, interp, TRUE);

            MP_TRACE_i(MP_FUNC, "set interp in request time pool 0x%lx",
                       (unsigned long)p);
        }
        else {
            MP_TRACE_i(MP_FUNC, "found interp in request time pool 0x%lx",
                       (unsigned long)p);
        }
    }

    return interp;
}

modperl_interp_t *modperl_interp_select(request_rec *r, conn_rec *c,
                                        server_rec *s)
{
    MP_dSCFG(s);
    MP_dRCFG;
    modperl_config_dir_t *dcfg = modperl_config_dir_get(r);
    const char *desc = NULL;
    modperl_interp_t *interp = NULL;
    apr_pool_t *p = NULL;
    int is_subrequest = (r && r->main) ? 1 : 0;
    modperl_interp_scope_e scope;

    if (!modperl_threaded_mpm()) {
        MP_TRACE_i(MP_FUNC,
                   "using parent 0x%lx for non-threaded mpm (%s:%d)",
                   (unsigned long)scfg->mip->parent,
                   s->server_hostname, s->port);
        /* XXX: if no VirtualHosts w/ PerlOptions +Parent we can skip this */
        PERL_SET_CONTEXT(scfg->mip->parent->perl);
        return scfg->mip->parent;
    }

    if (rcfg && rcfg->interp) {
        /* if scope is per-handler and something selected an interpreter
         * before modperl_callback_run_handlers() and is still holding it,
         * e.g. modperl_response_handler_cgi(), that interpreter will
         * be here
         */
        MP_TRACE_i(MP_FUNC,
                   "found interp 0x%lx in request config\n",
                   (unsigned long)rcfg->interp);
        return rcfg->interp;
    }

    /*
     * if a per-dir PerlInterpScope is specified, use it.
     * else if r != NULL use per-server PerlInterpScope
     * else scope must be per-connection
     */

    scope = (dcfg && !modperl_interp_scope_undef(dcfg)) ?
        dcfg->interp_scope :
        (r ? scfg->interp_scope : MP_INTERP_SCOPE_CONNECTION);

    MP_TRACE_i(MP_FUNC, "scope is per-%s",
               modperl_interp_scope_desc(scope));

    /*
     * XXX: goto modperl_interp_get() if scope == handler ?
     */

    if (c && (scope == MP_INTERP_SCOPE_CONNECTION)) {
        desc = "conn_rec pool";
        get_interp(c->pool);

        if (interp) {
            MP_TRACE_i(MP_FUNC,
                       "found interp 0x%lx in %s 0x%lx\n",
                       (unsigned long)interp, desc, (unsigned long)c->pool);
            return interp;
        }

        p = c->pool;
    }
    else if (r) {
        if (is_subrequest && (scope == MP_INTERP_SCOPE_REQUEST)) {
            /* share 1 interpreter across sub-requests */
            request_rec *main_r = r->main;

            while (main_r && !interp) {
                p = main_r->pool;
                get_interp(p);
                MP_TRACE_i(MP_FUNC,
                           "looking for interp in main request for %s...%s\n",
                           main_r->uri, interp ? "found" : "not found");
                main_r = main_r->main;
            }
        }
        else {
            p = r->pool;
            get_interp(p);
        }

        desc = "request_rec pool";

        if (interp) {
            MP_TRACE_i(MP_FUNC,
                       "found interp 0x%lx in %s 0x%lx (%s request for %s)\n",
                       (unsigned long)interp, desc, (unsigned long)p,
                       (is_subrequest ? "sub" : "main"), r->uri);
            return interp;
        }

        /* might have already been set by a ConnectionHandler */
        get_interp(r->connection->pool);

        if (interp) {
            desc = "r->connection pool";
            MP_TRACE_i(MP_FUNC,
                       "found interp 0x%lx in %s 0x%lx\n",
                       (unsigned long)interp, desc,
                       (unsigned long)r->connection->pool);
            return interp;
        }
    }

    interp = modperl_interp_get(s ? s : r->server);
    ++interp->num_requests; /* should only get here once per request */

    if (scope == MP_INTERP_SCOPE_HANDLER) {
        /* caller is responsible for calling modperl_interp_unselect() */
        interp->request = r;
        MpReqCLEANUP_REGISTERED_On(rcfg);
        MpInterpPUTBACK_On(interp);
    }
    else {
        if (!p) {
            /* should never happen */
            MP_TRACE_i(MP_FUNC, "no pool");
            return NULL;
        }

        set_interp(p);

#if AP_MODULE_MAGIC_AT_LEAST(20111130, 0)
        MP_TRACE_i(MP_FUNC,
                   "set interp 0x%lx in %s 0x%lx (%s request for %s)\n",
                   (unsigned long)interp, desc, (unsigned long)p,
                   (r ? (is_subrequest ? "sub" : "main") : "conn"),
                   (r ? r->uri : c->client_ip));
#else
        MP_TRACE_i(MP_FUNC,
                   "set interp 0x%lx in %s 0x%lx (%s request for %s)\n",
                   (unsigned long)interp, desc, (unsigned long)p,
                   (r ? (is_subrequest ? "sub" : "main") : "conn"),
                   (r ? r->uri : c->remote_ip));
#endif
    }

    /* set context (THX) for this thread */
    PERL_SET_CONTEXT(interp->perl);

    modperl_thx_interp_set(interp->perl, interp);

    return interp;
}

/* currently up to the caller if mip needs locking */
void modperl_interp_mip_walk(PerlInterpreter *current_perl,
                             PerlInterpreter *parent_perl,
                             modperl_interp_pool_t *mip,
                             modperl_interp_mip_walker_t walker,
                             void *data)
{
    modperl_list_t *head = mip->tipool ? mip->tipool->idle : NULL;

    if (!current_perl) {
        current_perl = PERL_GET_CONTEXT;
    }

    if (parent_perl) {
        PERL_SET_CONTEXT(parent_perl);
        walker(parent_perl, mip, data);
    }

    while (head) {
        PerlInterpreter *perl = ((modperl_interp_t *)head->data)->perl;
        PERL_SET_CONTEXT(perl);
        walker(perl, mip, data);
        head = head->next;
    }

    PERL_SET_CONTEXT(current_perl);
}

void modperl_interp_mip_walk_servers(PerlInterpreter *current_perl,
                                     server_rec *base_server,
                                     modperl_interp_mip_walker_t walker,
                                     void *data)
{
    server_rec *s = base_server->next;
    modperl_config_srv_t *base_scfg = modperl_config_srv_get(base_server);
    PerlInterpreter *base_perl = base_scfg->mip->parent->perl;

    modperl_interp_mip_walk(current_perl, base_perl,
                            base_scfg->mip, walker, data);

    while (s) {
        MP_dSCFG(s);
        PerlInterpreter *perl = scfg->mip->parent->perl;
        modperl_interp_pool_t *mip = scfg->mip;

        /* skip vhosts who share parent perl */
        if (perl == base_perl) {
            perl = NULL;
        }

        /* skip vhosts who share parent mip */
        if (scfg->mip == base_scfg->mip) {
            mip = NULL;
        }

        if (perl || mip) {
            modperl_interp_mip_walk(current_perl, perl,
                                    mip, walker, data);
        }

        s = s->next;
    }
}

#define MP_THX_INTERP_KEY "modperl2::thx_interp_key"
modperl_interp_t *modperl_thx_interp_get(PerlInterpreter *thx)
{
    modperl_interp_t *interp;
    dTHXa(thx);
    SV **svp = hv_fetch(PL_modglobal, MP_THX_INTERP_KEY, strlen(MP_THX_INTERP_KEY), 0);
    if (!svp) return NULL;
    interp = INT2PTR(modperl_interp_t *, SvIV(*svp));
    return interp;
}

void modperl_thx_interp_set(PerlInterpreter *thx, modperl_interp_t *interp)
{
    dTHXa(thx);
    (void)hv_store(PL_modglobal, MP_THX_INTERP_KEY, strlen(MP_THX_INTERP_KEY), newSViv(PTR2IV(interp)), 0);
    return;
}

#else

void modperl_interp_init(server_rec *s, apr_pool_t *p,
                         PerlInterpreter *perl)
{
    MP_dSCFG(s);
    scfg->perl = perl;
}

apr_status_t modperl_interp_cleanup(void *data)
{
    return APR_SUCCESS;
}

#endif /* USE_ITHREADS */
