#include "mod_perl.h"

/*
 * XXX: this is not the most efficent interpreter pool implementation
 * but it will do for proof-of-concept
 */

modperl_interp_t *modperl_interp_new(ap_pool_t *p,
                                     modperl_interp_t *parent)
{
    modperl_interp_t *interp = 
        (modperl_interp_t *)ap_pcalloc(p, sizeof(*interp));
    
    if (parent) {
        interp->mip_lock = parent->mip_lock;
    }

    fprintf(stderr, "modperl_interp_new: 0x%lx\n",
            (unsigned long)interp);

    return interp;
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
        fprintf(stderr, "modperl_interp_get: no pool, returning parent\n");
        return mip->parent;
    }

    ap_lock(mip->mip_lock);

    head = mip->head;

    fprintf(stderr, "modperl_interp_get: head == 0x%lx, parent == 0x%lx\n",
            (unsigned long)head, (unsigned long)mip->parent);

    while (head) {
        if (!MpInterpIN_USE(head)) {
            interp = head;
            fprintf(stderr, "modperl_interp_get: selected 0x%lx\n",
                    (unsigned long)interp);
#ifdef _PTHREAD_H
            fprintf(stderr, "pthread_self == 0x%lx\n",
                    (unsigned long)pthread_self());
#endif
            MpInterpIN_USE_On(interp);
            MpInterpPUTBACK_On(interp);
            break;
        }
        else {
            fprintf(stderr, "modperl_interp_get: 0x%lx in use\n",
                    (unsigned long)head);
            head = head->next;
        }
    }

    ap_unlock(mip->mip_lock);

    if (!interp) {
        /*
         * XXX: options
         * -block until one is available
         * -clone a new Perl
         * - ...
         */
    }

    return interp;
}

ap_status_t modperl_interp_pool_destroy(void *data)
{
    modperl_interp_pool_t *mip = (modperl_interp_pool_t *)data;

    while (mip->head) {
        dTHXa(mip->head->perl);

        fprintf(stderr, "modperl_interp_pool_destroy: head == 0x%lx",
                (unsigned long)mip->head);
        if (MpInterpIN_USE(mip->head)) {
            fprintf(stderr, " *error - still in use!*");
        }
        fprintf(stderr, "\n");

        PL_perl_destruct_level = 2;
        perl_destruct(mip->head->perl);
        perl_free(mip->head->perl);

        mip->head->perl = NULL;
        mip->head = mip->head->next;
    }

    fprintf(stderr, "modperl_interp_pool_destroy: parent == 0x%lx\n",
            (unsigned long)mip->parent);

    perl_destruct(mip->parent->perl);
    perl_free(mip->parent->perl);
    mip->parent->perl = NULL;

    ap_destroy_lock(mip->mip_lock);

    return APR_SUCCESS;
}

void modperl_interp_pool_init(server_rec *s, ap_pool_t *p,
                              PerlInterpreter *perl)
{
    MP_dSCFG(s);
    modperl_interp_pool_t *mip = 
        (modperl_interp_pool_t *)ap_pcalloc(p, sizeof(*mip));
    modperl_interp_t *cur_interp = NULL;
    ap_status_t rc;
    int i;

    rc = ap_create_lock(&mip->mip_lock, APR_MUTEX, APR_LOCKALL, "mip", p);

    if (rc != APR_SUCCESS) {
        exit(1); /*XXX*/
    }

    mip->parent = modperl_interp_new(p, NULL);
    mip->parent->perl = perl;
    mip->parent->mip_lock = mip->mip_lock;

#ifdef USE_ITHREADS
    mip->start = 3; /*XXX*/
    
    for (i=0; i<mip->start; i++) {
        modperl_interp_t *interp = modperl_interp_new(p, mip->parent);
        interp->perl = perl_clone(perl, TRUE);

        if (cur_interp) {
            cur_interp->next = interp;
            cur_interp = cur_interp->next;
        }
        else {
            mip->head = cur_interp = interp;
        }
    }
#endif

    fprintf(stderr, "modperl_interp_pool_init: parent == 0x%lx "
            "start=%d, min_spare=%d, max_spare=%d\n",
            (unsigned long)mip->parent, 
            mip->start, mip->min_spare, mip->max_spare);

    ap_register_cleanup(p, (void*)mip,
                        modperl_interp_pool_destroy, ap_null_cleanup);

    scfg->mip = mip;
}


ap_status_t modperl_interp_unselect(void *data)
{
    modperl_interp_t *interp = (modperl_interp_t *)data;

    ap_lock(interp->mip_lock);

    MpInterpIN_USE_Off(interp);

    fprintf(stderr, "modperl_interp_unselect: 0x%lx\n",
            (unsigned long)interp);

    ap_unlock(interp->mip_lock);

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
