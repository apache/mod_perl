#include "mod_perl.h"

/*
 * XXX: this is not the most efficent interpreter pool implementation
 * but it will do for proof-of-concept
 */

#ifdef USE_ITHREADS

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

        {
            /* XXX: hack for bug fixed in 5.6.1 */
            dTHXa(interp->perl);
            if (PL_scopestack_ix == 0) {
                ENTER;
            }
        }

        MpInterpCLONED_On(interp);
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
    dTHXa(interp->perl);

    MP_TRACE_i(MP_FUNC, "interp == 0x%lx\n",
               (unsigned long)interp);

    if (MpInterpIN_USE(interp)) {
        MP_TRACE_i(MP_FUNC, "*error - still in use!*\n");
    }

    PERL_SET_CONTEXT(interp->perl);
    PL_perl_destruct_level = 2;
    perl_destruct(interp->perl);
    perl_free(interp->perl);
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

    modperl_tipool_putback_data(mip->tipool, data, interp->num_requests);

    return APR_SUCCESS;
}

/* XXX:
 * interp is marked as in_use for the lifetime of the pool it is
 * stashed in.  this is done to avoid the tipool->tlock whenever
 * possible.  neither approach is ideal.
 */
#define MP_INTERP_KEY "MODPERL_INTERP"

modperl_interp_t *modperl_interp_select(request_rec *rr, conn_rec *c,
                                        server_rec *s)
{
    MP_dSCFG(s);
    modperl_dir_config_t *dcfg = modperl_dir_config_get(rr);
    const char *desc = NULL;
    modperl_interp_t *interp;
    apr_pool_t *p = NULL;
    request_rec *r = rr;
    int is_subrequest = (rr && rr->main) ? 1 : 0;
    modperl_interp_lifetime_e lifetime;

    if (!scfg->threaded_mpm) {
        MP_TRACE_i(MP_FUNC,
                   "using parent 0x%lx for non-threaded mpm (%s:%d)\n",
                   (unsigned long)scfg->mip->parent,
                   s->server_hostname, s->port);
        /* XXX: if no VirtualHosts w/ PerlOptions +Parent we can skip this */
        PERL_SET_CONTEXT(scfg->mip->parent->perl);
        return scfg->mip->parent;
    }

    /*
     * if a per-dir PerlInterpLifetime is specified, use it.
     * else if r != NULL use per-server PerlInterpLifetime
     * else lifetime must be per-connection
     */

    lifetime = (dcfg && !modperl_interp_lifetime_undef(dcfg)) ? 
        dcfg->interp_lifetime :
        (r ? scfg->interp_lifetime : MP_INTERP_LIFETIME_CONNECTION);

    MP_TRACE_i(MP_FUNC, "lifetime is per-%s\n",
               modperl_interp_lifetime_desc(lifetime));

    if (is_subrequest && (lifetime == MP_INTERP_LIFETIME_REQUEST)) {
        /* share 1 interpreter across sub-requests */
        r = r->main;
    }

    if (c && (lifetime == MP_INTERP_LIFETIME_CONNECTION)) {
        desc = "conn_rec pool";
        (void)apr_pool_userdata_get((void **)&interp, MP_INTERP_KEY, c->pool);

        if (interp) {
            MP_TRACE_i(MP_FUNC,
                       "found interp 0x%lx in %s 0x%lx\n",
                       (unsigned long)interp, desc, (unsigned long)c->pool);
            return interp;
        }

        p = c->pool;
    }
    else if (r) {
        desc = "request_rec pool";
        (void)apr_pool_userdata_get((void **)&interp, MP_INTERP_KEY, r->pool);

        if (interp) {
            MP_TRACE_i(MP_FUNC,
                       "found interp 0x%lx in %s 0x%lx (%s request for %s)\n",
                       (unsigned long)interp, desc, (unsigned long)r->pool,
                       (is_subrequest ? "sub" : "main"), rr->uri);
            return interp;
        }

        /* might have already been set by a ConnectionHandler */
        (void)apr_pool_userdata_get((void **)&interp, MP_INTERP_KEY,
                                    r->connection->pool);
        if (interp) {
            desc = "r->connection pool";
            MP_TRACE_i(MP_FUNC,
                       "found interp 0x%lx in %s 0x%lx\n",
                       (unsigned long)interp, desc,
                       (unsigned long)r->connection->pool);
            return interp;
        }

        p = r->pool;
    }

    if (!p) {
        /* should never happen */
        MP_TRACE_i(MP_FUNC, "no pool\n");
        return NULL;
    }

    interp = modperl_interp_get(s ? s : r->server);
    ++interp->num_requests; /* should only get here once per request */

    (void)apr_pool_userdata_set((void *)interp, MP_INTERP_KEY,
                                modperl_interp_unselect,
                                p);

    /* set context (THX) for this thread */
    PERL_SET_CONTEXT(interp->perl);

    MP_TRACE_i(MP_FUNC, "set interp 0x%lx in %s 0x%lx (%s request for %s)\n",
               (unsigned long)interp, desc, (unsigned long)p,
               (r ? (is_subrequest ? "sub" : "main") : "conn"),
               (r ? rr->uri : c->remote_ip));

    return interp;
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
