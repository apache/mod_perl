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

modperl_interp_t *modperl_interp_new(apr_pool_t *p,
                                     modperl_interp_pool_t *mip,
                                     PerlInterpreter *perl)
{
    modperl_interp_t *interp = 
        (modperl_interp_t *)apr_pcalloc(p, sizeof(*interp));
    
    interp->mip = mip;

    if (perl) {
#ifdef MP_USE_GTOP
        MP_dSCFG(mip->server);
        MP_TRACE_m_do(
            modperl_gtop_do_proc_mem_before(MP_FUNC ": perl_clone");
        );
#endif

        interp->perl = perl_clone(perl, FALSE);

        modperl_interp_clone_init(interp);

        PERL_SET_CONTEXT(mip->parent->perl);

#ifdef MP_USE_GTOP
        MP_TRACE_m_do(
            modperl_gtop_do_proc_mem_after(MP_FUNC ": perl_clone");
        );
#endif
    }

    MP_TRACE_i(MP_FUNC, "0x%lx\n", (unsigned long)interp);

    return interp;
}

void modperl_interp_destroy(modperl_interp_t *interp)
{
    apr_pool_t *p = NULL;
    apr_array_header_t *handles;
    dTHXa(interp->perl);

    MP_TRACE_i(MP_FUNC, "interp == 0x%lx\n",
               (unsigned long)interp);

    if (MpInterpIN_USE(interp)) {
        MP_TRACE_i(MP_FUNC, "*error - still in use!*\n");
    }

    /* we cant use interp->mip->ap_pool without locking
     * apr_pool_create() will mutex lock for us
     * XXX: could roll something without using apr_pool_t
     * to avoid locking
     */
    (void)apr_pool_create(&p, NULL);
    handles = modperl_xs_dl_handles_get(aTHX_ p);

    modperl_perl_destruct(interp->perl);

    if (handles) {
        modperl_xs_dl_handles_close(p, handles);
    }

    apr_pool_destroy(p);
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

    MP_TRACE_i(MP_FUNC, "head == 0x%lx, parent == 0x%lx\n",
               (unsigned long)head, (unsigned long)mip->parent);

    MP_TRACE_i(MP_FUNC, "selected 0x%lx (perl==0x%lx)\n",
               (unsigned long)interp,
               (unsigned long)interp->perl);

#ifdef MP_TRACE
    interp->tid = MP_TIDF;
    MP_TRACE_i(MP_FUNC, "thread == 0x%lx\n", interp->tid);
#endif

    MpInterpIN_USE_On(interp);

    return interp;
}

apr_status_t modperl_interp_pool_destroy(void *data)
{
    modperl_interp_pool_t *mip = (modperl_interp_pool_t *)data;

    modperl_tipool_destroy(mip->tipool);
    mip->tipool = NULL;

    if (MpInterpBASE(mip->parent)) {
        /* multiple mips might share the same parent
         * make sure its only destroyed once
         */
        MP_TRACE_i(MP_FUNC, "parent == 0x%lx\n",
                   (unsigned long)mip->parent);

        modperl_interp_destroy(mip->parent);
    }

    mip->parent->perl = NULL;

    return APR_SUCCESS;
}

static void *interp_pool_grow(modperl_tipool_t *tipool, void *data)
{
    modperl_interp_pool_t *mip = (modperl_interp_pool_t *)data;
    MP_TRACE_i(MP_FUNC, "adding new interpreter to the pool\n");
    return (void *)modperl_interp_new(mip->ap_pool, mip, mip->parent->perl);
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
        MP_TRACE_i(MP_FUNC, "listp==0x%lx, interp==0x%lx, requests=%d\n",
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
    pTHX;
    MP_dSCFG(s);

    modperl_interp_pool_t *mip = 
        (modperl_interp_pool_t *)apr_pcalloc(p, sizeof(*mip));

    modperl_tipool_t *tipool = 
        modperl_tipool_new(p, scfg->interp_pool_cfg,
                           &interp_pool_func, mip);

    mip->tipool = tipool;
    mip->ap_pool = p;
    mip->server  = s;
    mip->parent = modperl_interp_new(p, mip, NULL);
    aTHX = mip->parent->perl = perl;
    
    /* this happens post-config in mod_perl.c:modperl_init_clones() */
    /* modperl_tipool_init(tipool); */

    apr_pool_cleanup_register(p, (void*)mip,
                              modperl_interp_pool_destroy,
                              apr_pool_cleanup_null);

    scfg->mip = mip;
}

apr_status_t modperl_interp_unselect(void *data)
{
    modperl_interp_t *interp = (modperl_interp_t *)data;
    modperl_interp_pool_t *mip = interp->mip;

    MpInterpIN_USE_Off(interp);
    MpInterpPUTBACK_Off(interp);

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

    if (!scfg->threaded_mpm) {
        MP_TRACE_i(MP_FUNC,
                   "using parent 0x%lx for non-threaded mpm (%s:%d)\n",
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

    MP_TRACE_i(MP_FUNC, "scope is per-%s\n",
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
        MpInterpPUTBACK_On(interp);
    }
    else {
        if (!p) {
            /* should never happen */
            MP_TRACE_i(MP_FUNC, "no pool\n");
            return NULL;
        }

        (void)apr_pool_userdata_set((void *)interp, MP_INTERP_KEY,
                                    modperl_interp_unselect,
                                    p);

        MP_TRACE_i(MP_FUNC,
                   "set interp 0x%lx in %s 0x%lx (%s request for %s)\n",
                   (unsigned long)interp, desc, (unsigned long)p,
                   (r ? (is_subrequest ? "sub" : "main") : "conn"),
                   (r ? r->uri : c->remote_ip));
    }

    /* set context (THX) for this thread */
    PERL_SET_CONTEXT(interp->perl);

    return interp;
}

/* currently up to the caller if mip needs locking */
void modperl_interp_mip_walk(PerlInterpreter *current_perl,
                             PerlInterpreter *parent_perl,
                             modperl_interp_pool_t *mip,
                             modperl_interp_mip_walker_t walker,
                             void *data)
{
    modperl_list_t *head = mip->tipool->idle;

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
