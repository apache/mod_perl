#include "mod_perl.h"

/*
 * XXX: this is not the most efficent interpreter pool implementation
 * but it will do for proof-of-concept
 */

#ifdef USE_ITHREADS

modperl_list_t *modperl_list_new(ap_pool_t *p)
{
    modperl_list_t *listp = 
        (modperl_list_t *)ap_pcalloc(p, sizeof(*listp));
    return listp;
}

void modperl_list_dump(modperl_list_t *listp)
{
    while (listp->next) {
        modperl_interp_t *interp = (modperl_interp_t *)listp->data;
        MP_TRACE_i(MP_FUNC, "listp==0x%lx, interp==0x%lx, requests=%d\n",
                 (unsigned long)listp, (unsigned long)interp,
                 interp->num_requests);
        listp = listp->next;
    }
}

modperl_list_t *modperl_list_last(modperl_list_t *list)
{
    while (list->next) {
        list = list->next;
    }

    return list;
}

modperl_list_t *modperl_list_first(modperl_list_t *list)
{
    while (list->prev) {
        list = list->prev;
    }

    return list;
}

modperl_list_t *
modperl_list_append(modperl_list_t *list,
                    modperl_list_t *new_list)
{
    modperl_list_t *last;

    new_list->prev = new_list->next = NULL;

    if (!list) {
        return new_list;
    }

    last = modperl_list_last(list);

    last->next = new_list;
    new_list->prev = last;

    return list;
}

modperl_list_t *
modperl_list_prepend(modperl_list_t *list,
                     modperl_list_t *new_list)
{
    new_list->prev = new_list->next = NULL;

    if (!list) {
        return new_list;
    }

    if (list->prev) {
        list->prev->next = new_list;
        new_list->prev = list->prev;
    }

    list->prev = new_list;
    new_list->next = list;

    return new_list;
}

modperl_list_t *
modperl_list_remove(modperl_list_t *list,
                    modperl_list_t *rlist)
{
    modperl_list_t *tmp = list;
  
    while (tmp) {
        if (tmp != rlist) {
            tmp = tmp->next;
        }
        else {
            if (tmp->prev) {
                tmp->prev->next = tmp->next;
            }
            if (tmp->next) {
                tmp->next->prev = tmp->prev;
            }
            if (list == tmp) {
                list = list->next;
            }

            break;
	}
    }

#ifdef MP_TRACE
    if (!tmp) {
        /* should never happen */
        MP_TRACE_i(MP_FUNC, "failed to find 0x%lx in list 0x%lx\n",
                   (unsigned long)rlist, (unsigned long)list);
        modperl_list_dump(list);
    }
#endif

    return list;
}

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
    modperl_interp_t *interp = NULL;
    modperl_interp_pool_t *mip = scfg->mip;
    modperl_list_t *head;

    MUTEX_LOCK(&mip->mip_lock);

    if (mip->size == mip->in_use) {
        if (mip->size < mip->cfg->max) {
            interp = modperl_interp_new(mip->ap_pool, mip, 
                                        mip->parent->perl);
            MUTEX_UNLOCK(&mip->mip_lock);
            modperl_interp_pool_add(mip, interp);
            MP_TRACE_i(MP_FUNC, "cloned new interp\n");
        }
        while (mip->size == mip->in_use) {
            MP_TRACE_i(MP_FUNC, "waiting for available interpreter\n");
            COND_WAIT(&mip->available, &mip->mip_lock);
        }
    }

    head = mip->idle;
    mip->idle = modperl_list_remove(mip->idle, head);
    mip->busy = modperl_list_append(mip->busy, head);

    interp = (modperl_interp_t *)head->data;

    MP_TRACE_i(MP_FUNC, "head == 0x%lx, parent == 0x%lx\n",
               (unsigned long)head, (unsigned long)mip->parent);

    MP_TRACE_i(MP_FUNC, "selected 0x%lx (perl==0x%lx)\n",
               (unsigned long)interp,
               (unsigned long)interp->perl);
#ifdef _PTHREAD_H
    MP_TRACE_i(MP_FUNC, "pthread_self == 0x%lx\n",
               (unsigned long)pthread_self());
#endif

    MpInterpIN_USE_On(interp);
    mip->in_use++;

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

    while (mip->idle) {
        modperl_interp_destroy((modperl_interp_t *)mip->idle->data);
        mip->size--;
        mip->idle = mip->idle->next;
    }

    if (mip->busy) {
        MP_TRACE_i(MP_FUNC, "ERROR: %d interpreters still in use\n",
                   mip->in_use);
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
    modperl_list_t *new_list = modperl_list_new(mip->ap_pool);

    MUTEX_LOCK(&mip->mip_lock);

    interp->listp = new_list;
    new_list->data = (void *)interp;
    mip->idle = modperl_list_append(mip->idle, new_list);

    mip->size++;
    MP_TRACE_i(MP_FUNC, "added 0x%lx (size=%d)\n",
               (unsigned long)interp, mip->size);

    MUTEX_UNLOCK(&mip->mip_lock);
}

void modperl_interp_pool_remove(modperl_interp_pool_t *mip,
                                modperl_interp_t *interp)
{
    MUTEX_LOCK(&mip->mip_lock);

    mip->idle = modperl_list_remove(mip->idle, interp->listp);

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

    /* remove from busy list, add back to idle */
    /* XXX: sort list on interp->num_requests */
    mip->busy = modperl_list_remove(mip->busy, interp->listp);
    mip->idle = modperl_list_prepend(mip->idle, interp->listp);

    if (!mip->busy) {
        MP_TRACE_i(MP_FUNC, "all interpreters idle:\n");
        MP_TRACE_i_do(modperl_list_dump(mip->idle));
    }

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
    ++interp->num_requests; /* should only get here once per request */

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
