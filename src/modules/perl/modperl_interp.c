#include "mod_perl.h"

/*
 * XXX: this is not the most efficent interpreter pool implementation
 * but it will do for proof-of-concept
 */

#ifdef USE_ITHREADS

modperl_interp_t *modperl_interp_new(ap_pool_t *p,
                                     modperl_interp_pool_t *mip,
                                     PerlInterpreter *perl)
{
    modperl_interp_t *interp = 
        (modperl_interp_t *)ap_pcalloc(p, sizeof(*interp));
    
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

ap_status_t modperl_interp_cleanup(void *data)
{
    modperl_interp_destroy((modperl_interp_t *)data);
    return APR_SUCCESS;
}

modperl_interp_t *modperl_interp_get(server_rec *s)
{
    MP_dSCFG(s);
    modperl_interp_t *head, *interp = NULL;
    modperl_interp_pool_t *mip = scfg->mip;

    if (!mip->head) {
        /*
         * XXX: no interp pool
         * need to lock the interpreter during callbacks
         * unless mpm is prefork
         */
        MP_TRACE_i(MP_FUNC, "no pool, returning parent\n");
        return mip->parent;
    }

    MUTEX_LOCK(&mip->mip_lock);

    if (mip->size == mip->in_use) {
        if (mip->size < mip->cfg->max) {
            interp = modperl_interp_new(mip->ap_pool, mip, 
                                        mip->parent->perl);
            MUTEX_UNLOCK(&mip->mip_lock);
            modperl_interp_pool_add(mip, interp);
            MP_TRACE_i(MP_FUNC, "cloned new interp\n");
            return interp;
        }
        while (mip->size == mip->in_use) {
            MP_TRACE_i(MP_FUNC, "waiting for available interpreter\n");
            COND_WAIT(&mip->available, &mip->mip_lock);
        }
    }

    head = mip->head;

    MP_TRACE_i(MP_FUNC, "head == 0x%lx, parent == 0x%lx\n",
               (unsigned long)head, (unsigned long)mip->parent);

    while (head) {
        if (!MpInterpIN_USE(head)) {
            interp = head;
            MP_TRACE_i(MP_FUNC, "selected 0x%lx (perl==0x%lx)\n",
                       (unsigned long)interp,
                       (unsigned long)interp->perl);
#ifdef _PTHREAD_H
            MP_TRACE_i(MP_FUNC, "pthread_self == 0x%lx\n",
                       (unsigned long)pthread_self());
#endif
            MpInterpIN_USE_On(interp);
            mip->in_use++;
            break;
        }
        else {
            MP_TRACE_i(MP_FUNC, "0x%lx in use\n",
                       (unsigned long)head);
            head = head->next;
        }
    }

    /* XXX: this should never happen */
    if (!interp) {
        MP_TRACE_i(MP_FUNC, "PANIC: no interpreter found, %d of %d in use\n", 
                   mip->in_use, mip->size);
        abort();
    }

    MUTEX_UNLOCK(&mip->mip_lock);

    return interp;
}

ap_status_t modperl_interp_pool_destroy(void *data)
{
    modperl_interp_pool_t *mip = (modperl_interp_pool_t *)data;
    modperl_interp_t *interp;

    while ((interp = mip->head)) {
        modperl_interp_pool_remove(mip, interp);
        modperl_interp_destroy(interp);
    }

    MP_TRACE_i(MP_FUNC, "parent == 0x%lx\n",
               (unsigned long)mip->parent);

    modperl_interp_destroy(mip->parent);
    mip->parent->perl = NULL;

    MUTEX_DESTROY(&mip->mip_lock);

    COND_DESTROY(&mip->available);

    return APR_SUCCESS;
}

void modperl_interp_pool_add(modperl_interp_pool_t *mip,
                             modperl_interp_t *interp)
{
    MUTEX_LOCK(&mip->mip_lock);

    if (mip->size == 0) {
        mip->head = mip->tail = interp;
    }
    else {
        mip->tail->next = interp;
        mip->tail = interp;
    }

    mip->size++;
    MP_TRACE_i(MP_FUNC, "added 0x%lx (size=%d)\n",
               (unsigned long)interp, mip->size);

    MUTEX_UNLOCK(&mip->mip_lock);
}

void modperl_interp_pool_remove(modperl_interp_pool_t *mip,
                                modperl_interp_t *interp)
{
    MUTEX_LOCK(&mip->mip_lock);

    if (mip->head == interp) {
        mip->head = interp->next;
        interp->next = NULL;
        MP_TRACE_i(MP_FUNC, "shifting head from 0x%lx to 0x%lx\n",
                   (unsigned long)interp, (unsigned long)mip->head);
    }
    else if (mip->tail == interp) {
        modperl_interp_t *tmp = mip->head;
        /* XXX: implement a prev pointer */
        while (tmp->next && tmp->next->next) {
            tmp = tmp->next;
        }

        tmp->next = NULL;
        mip->tail = tmp;
        MP_TRACE_i(MP_FUNC, "popping tail 0x%lx, now 0x%lx\n",
                   (unsigned long)interp, (unsigned long)mip->tail);
    }
    else {
        modperl_interp_t *tmp = mip->head;

        while (tmp && tmp->next != interp) {
            tmp = tmp->next;
        }

        if (!tmp) {
            MP_TRACE_i(MP_FUNC, "0x%lx not found\n",
                       (unsigned long)interp);
            MUTEX_UNLOCK(&mip->mip_lock);
            return;
        }
        tmp->next = tmp->next->next;
    }

    mip->size--;
    MP_TRACE_i(MP_FUNC, "removed 0x%lx (size=%d)\n",
               (unsigned long)interp, mip->size);

    MUTEX_UNLOCK(&mip->mip_lock);
}

void modperl_interp_init(server_rec *s, ap_pool_t *p,
                         PerlInterpreter *perl)
{
    pTHX;
    MP_dSCFG(s);
    modperl_interp_pool_t *mip = 
        (modperl_interp_pool_t *)ap_pcalloc(p, sizeof(*mip));
    int i;

    mip->ap_pool = p;
    mip->server  = s;
    mip->cfg = scfg->interp_pool_cfg;
    mip->parent = modperl_interp_new(p, mip, NULL);
    aTHX = mip->parent->perl = perl;
    
    MUTEX_INIT(&mip->mip_lock);
    COND_INIT(&mip->available);

    for (i=0; i<mip->cfg->start; i++) {
        modperl_interp_t *interp = modperl_interp_new(p, mip, perl);

        modperl_interp_pool_add(mip, interp);
    }

    MP_TRACE_i(MP_FUNC, "parent == 0x%lx "
               "start=%d, max=%d, min_spare=%d, max_spare=%d\n",
               (unsigned long)mip->parent, 
               mip->cfg->start, mip->cfg->max,
               mip->cfg->min_spare, mip->cfg->max_spare);

    ap_register_cleanup(p, (void*)mip,
                        modperl_interp_pool_destroy, ap_null_cleanup);

    scfg->mip = mip;
}

ap_status_t modperl_interp_unselect(void *data)
{
    modperl_interp_t *interp = (modperl_interp_t *)data;
    modperl_interp_pool_t *mip = interp->mip;

    MUTEX_LOCK(&mip->mip_lock);

    MpInterpIN_USE_Off(interp);

    mip->in_use--;

    MP_TRACE_i(MP_FUNC, "0x%lx now available (%d in use, %d running)\n",
               (unsigned long)interp, mip->in_use, mip->size);

    if (mip->in_use == (mip->cfg->max - 1)) {
        MP_TRACE_i(MP_FUNC, "broadcast available\n");
        COND_SIGNAL(&mip->available);
    }
    else if (mip->size > mip->cfg->max_spare) {
        MP_TRACE_i(MP_FUNC, "throttle down (max_spare=%d, %d running)\n",
                   mip->cfg->max_spare, mip->size);
        MUTEX_UNLOCK(&mip->mip_lock);
        modperl_interp_pool_remove(mip, interp);
        modperl_interp_destroy(interp);
        return APR_SUCCESS;
    }

    MUTEX_UNLOCK(&mip->mip_lock);

    return APR_SUCCESS;
}

/* XXX:
 * interp is marked as in_use for the lifetime of the pool it is
 * stashed in.  this is done to avoid the mip->mip_lock whenever
 * possible.  neither approach is ideal.
 */
#define MP_INTERP_KEY "MODPERL_INTERP"

modperl_interp_t *modperl_interp_select(request_rec *r, conn_rec *c,
                                        server_rec *s)
{
    modperl_interp_t *interp;
    ap_pool_t *p = NULL;
    const char *desc = NULL;

    if (c) {
        desc = "conn_rec pool";
        (void)ap_get_userdata((void **)&interp, MP_INTERP_KEY, c->pool);

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
        (void)ap_get_userdata((void **)&interp, MP_INTERP_KEY, r->pool);

        if (interp) {
            MP_TRACE_i(MP_FUNC,
                       "found interp 0x%lx in %s 0x%lx\n",
                       (unsigned long)interp, desc, (unsigned long)r->pool);
            return interp;
        }

        /* might have already been set by a ConnectionHandler */
        (void)ap_get_userdata((void **)&interp, MP_INTERP_KEY,
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

    (void)ap_set_userdata((void *)interp, MP_INTERP_KEY,
                          modperl_interp_unselect,
                          p);

    MP_TRACE_i(MP_FUNC, "set interp 0x%lx in %s 0x%lx\n",
               (unsigned long)interp, desc, (unsigned long)p);

    return interp;
}

#else

void modperl_interp_init(server_rec *s, ap_pool_t *p,
                         PerlInterpreter *perl)
{
    MP_dSCFG(s);
    scfg->perl = perl;
}

ap_status_t modperl_interp_cleanup(void *data)
{
    return APR_SUCCESS;
}

#endif /* USE_ITHREADS */
