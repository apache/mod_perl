#include "mod_perl.h"

/*
 * XXX: this is not the most efficent interpreter pool implementation
 * but it will do for proof-of-concept
 */

modperl_interp_t *modperl_interp_new(ap_pool_t *p,
                                     modperl_interp_pool_t *mip,
                                     PerlInterpreter *perl)
{
    modperl_interp_t *interp = 
        (modperl_interp_t *)ap_pcalloc(p, sizeof(*interp));
    
    if (mip) {
        interp->mip = mip;
    }

    if (perl) {
        interp->perl = perl_clone(perl, TRUE);
        MpInterpCLONED_On(interp);
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
            MP_TRACE_i(MP_FUNC, "selected 0x%lx\n",
                       (unsigned long)interp);
#ifdef _PTHREAD_H
            MP_TRACE_i(MP_FUNC, "pthread_self == 0x%lx\n",
                       (unsigned long)pthread_self());
#endif
            MpInterpIN_USE_On(interp);
            MpInterpPUTBACK_On(interp);
            mip->in_use++;
            break;
        }
        else {
            MP_TRACE_i(MP_FUNC, "0x%lx in use\n",
                       (unsigned long)head);
            head = head->next;
        }
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

void modperl_interp_pool_init(server_rec *s, ap_pool_t *p,
                              PerlInterpreter *perl)
{
    pTHX;
    MP_dSCFG(s);
    modperl_interp_pool_t *mip = 
        (modperl_interp_pool_t *)ap_pcalloc(p, sizeof(*mip));
    int i;

    mip->ap_pool = p;
    mip->cfg = scfg->interp_pool_cfg;
    mip->parent = modperl_interp_new(p, mip, NULL);
    aTHX = mip->parent->perl = perl;
    
    MUTEX_INIT(&mip->mip_lock);
    COND_INIT(&mip->available);

#ifdef USE_ITHREADS
    for (i=0; i<mip->cfg->start; i++) {
        modperl_interp_t *interp = modperl_interp_new(p, mip, perl);

        modperl_interp_pool_add(mip, interp);
    }
#endif

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

int modperl_interp_select(request_rec *r)
{
    modperl_interp_t *interp = modperl_interp_get(r->server);

    /* XXX: stash interp pointer in r->per_request */

    if (MpInterpPUTBACK(interp)) {
        ap_register_cleanup(r->pool, (void*)interp,
                            modperl_interp_unselect, ap_null_cleanup);
    }

    if (1) { /* testing concurrent callbacks into the Perl runtime(s) */
        dTHXa(interp->perl);
        SV *sv = get_sv("Apache::Server::Perl", TRUE);
        sv_setref_pv(sv, Nullch, (void*)interp->perl);
        eval_pv("printf STDERR qq(Perl == 0x%lx\n), "
                "$$Apache::Server::Perl", TRUE);
    }

    return OK;
}
