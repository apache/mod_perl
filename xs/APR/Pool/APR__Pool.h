/* Copyright 2001-2004 The Apache Software Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#define MP_APR_POOL_NEW "APR::Pool::new"

typedef struct {
    SV *sv;
} mpxs_pool_account_t;

/* XXX: this implementation has a problem with perl ithreads. if a
 * custom pool is allocated, and then a thread is spawned we now have
 * two copies of the pool object, each living in a different perl
 * interpreter, both pointing to the same memory address of the apr
 * pool.
 *
 * need to write a CLONE class method could properly clone the
 * thread's copied object, but it's tricky:
 * - it needs to call parent_get() on the copied object and allocate a
 *   new pool from that parent's pool
 * - it needs to reinstall any registered cleanup callbacks (can we do
 *   that?) may be we can skip those?
 */

/* XXX: should we make it a new global tracing category
 * MOD_PERL_TRACE=p for tracing pool management? */
#define MP_POOL_TRACE_DO 0

#if MP_POOL_TRACE_DO && defined(MP_TRACE)
#define MP_POOL_TRACE modperl_trace
#else
#define MP_POOL_TRACE if (0) modperl_trace
#endif

/* invalidate all Perl objects referencing the data sv stored in the
 * pool and the sv itself. this is needed when a parent pool triggers
 * apr_pool_destroy on its child pools
 */
static MP_INLINE apr_status_t
mpxs_apr_pool_cleanup(void *cleanup_data)
{
    mpxs_pool_account_t *data;
    apr_pool_userdata_get((void **)&data, MP_APR_POOL_NEW,
                          (apr_pool_t *)cleanup_data);
    if (!(data && data->sv)) {
        /* if there is no data, there is nothing to unset */
        MP_POOL_TRACE(MP_FUNC, "this pool seems to be destroyed already");
    }
    else {
        MP_POOL_TRACE(MP_FUNC,
                      "pool 0x%lx contains a valid sv 0x%lx, invalidating it",
                      (unsigned long)data->sv, (unsigned long)cleanup_data);

        /* invalidate all Perl objects referencing this sv */
        SvIVX(data->sv) = 0;

        /* invalidate the reference stored in the pool */
        data->sv = NULL;
        /* data->sv will go away by itself when all objects will go away */
    }

    return APR_SUCCESS;
}

/**
 * Create a new pool or subpool.
 * @param  parent_pool_obj   an APR::Pool object or an "APR::Pool" class
 * @return                   a new pool or subpool
 */
static MP_INLINE SV *mpxs_apr_pool_create(pTHX_ SV *parent_pool_obj)
{
    apr_pool_t *parent_pool = mpxs_sv_object_deref(parent_pool_obj, apr_pool_t);
    apr_pool_t *child_pool  = NULL;

    MP_POOL_TRACE(MP_FUNC, "parent pool 0x%lx\n", (unsigned long)parent_pool);
    (void)apr_pool_create(&child_pool, parent_pool);

#if APR_POOL_DEBUG
    /* useful for pools debugging, can grep for APR::Pool::new */
    apr_pool_tag(child_pool, MP_APR_POOL_NEW);
#endif

    /* allocation corruption validation: I saw this happening when the
     * same pool was destroyed more than once, should be fixed now,
     * but still the check is not redundant */
    if (child_pool == parent_pool) {
        Perl_croak(aTHX_ "a newly allocated sub-pool 0x%lx "
                   "is the same as its parent 0x%lx, aborting",
                   (unsigned long)child_pool, (unsigned long)parent_pool);
    }

    /* Each newly created pool must be destroyed only once. Calling
     * apr_pool_destroy will destroy the pool and its children pools,
     * however a perl object for a sub-pool will still keep a pointer
     * to the pool which was already destroyed. When this object is
     * DESTROYed, apr_pool_destroy will be called again. In the best
     * case it'll try to destroy a non-existing pool, but in the worst
     * case it'll destroy a different valid pool which has been given
     * the same memory allocation wrecking havoc. Therefore we must
     * ensure that when sub-pools are destroyed via the parent pool,
     * their cleanup callbacks will destroy the guts of their perl
     * objects, so when those perl objects, pointing to memory
     * previously allocated by destroyed sub-pools or re-used already
     * by new pools, will get their time to DESTROY, they won't make a
     * mess, trying to destroy an already destroyed pool or even worse
     * a pool allocate in the place of the old one.
     */
    apr_pool_cleanup_register(child_pool, (void *)child_pool,
                              mpxs_apr_pool_cleanup,
                              apr_pool_cleanup_null);
#if APR_POOL_DEBUG
    /* child <-> parent <-> ... <-> top ancestry traversal */
    {
        apr_pool_t *p = child_pool;
        apr_pool_t *pp;

        while ((pp = apr_pool_parent_get(p))) {
            MP_POOL_TRACE(MP_FUNC, "parent 0x%lx, child 0x%lx\n",
                    (unsigned long)pp, (unsigned long)p);

            if (apr_pool_is_ancestor(pp, p)) {
                MP_POOL_TRACE(MP_FUNC, "0x%lx is a subpool of 0x%lx\n",
                        (unsigned long)p, (unsigned long)pp);
            }
            p = pp;
        }
    }
#endif

    {
        mpxs_pool_account_t *data =
            (mpxs_pool_account_t *)apr_pcalloc(child_pool, sizeof(*data));

        SV *rv = sv_setref_pv(NEWSV(0, 0), "APR::Pool", (void*)child_pool);

        data->sv = SvRV(rv);

        MP_POOL_TRACE(MP_FUNC, "sub-pool p: 0x%lx, sv: 0x%lx, rv: 0x%lx",
                      (unsigned long)child_pool, data->sv, rv);

        apr_pool_userdata_set(data, MP_APR_POOL_NEW, NULL, child_pool);

        return rv;
    }
}

typedef struct {
    SV *cv;
    SV *arg;
    apr_pool_t *p;
    PerlInterpreter *perl;
#ifdef USE_ITHREADS
    modperl_interp_t *interp;
#endif
} mpxs_cleanup_t;

/**
 * callback wrapper for Perl cleanup subroutines
 * @param data   internal storage
 */
static apr_status_t mpxs_cleanup_run(void *data)
{
    int count;
    apr_status_t status = APR_SUCCESS;
    mpxs_cleanup_t *cdata = (mpxs_cleanup_t *)data;
    dTHXa(cdata->perl);
    dSP;

    ENTER;SAVETMPS;
    PUSHMARK(SP);
    if (cdata->arg) {
        XPUSHs(cdata->arg);
    }
    PUTBACK;

    count = call_sv(cdata->cv, G_SCALAR|G_EVAL);

    SPAGAIN;

    if (count == 1) {
        status = POPi;
    }

    PUTBACK;
    FREETMPS;LEAVE;

    if (SvTRUE(ERRSV)) {
        /*XXX*/
    }

    SvREFCNT_dec(cdata->cv);
    if (cdata->arg) {
        SvREFCNT_dec(cdata->arg);
    }

#ifdef USE_ITHREADS
    if (cdata->interp) {
        /* this will decrement the interp refcnt until
         * there are no more references, in which case
         * the interpreter will be putback into the mip
         */
        (void)modperl_interp_unselect(cdata->interp);
    }
#endif

    return status;
}

/**
 * run registered cleanups
 * @param p      pool with which to associate the cleanup
 * @param cv     subroutine reference to run
 * @param arg    optional argument to pass to the subroutine
 */
static MP_INLINE void mpxs_apr_pool_cleanup_register(pTHX_ apr_pool_t *p,
                                                     SV *cv, SV *arg)
{
    mpxs_cleanup_t *data =
        (mpxs_cleanup_t *)apr_pcalloc(p, sizeof(*data));

    data->cv = SvREFCNT_inc(cv);
    data->arg = arg ? SvREFCNT_inc(arg) : Nullsv;
    data->p = p;
#ifdef USE_ITHREADS
    data->perl = aTHX;
    /* make sure interpreter is not putback into the mip
     * until this cleanup has run.
     */
    if ((data->interp = MP_THX_INTERP_GET(data->perl))) {
        data->interp->refcnt++;
    }
#endif

    apr_pool_cleanup_register(p, data,
                              mpxs_cleanup_run,
                              apr_pool_cleanup_null);
}


static MP_INLINE SV *
mpxs_apr_pool_parent_get(pTHX_ apr_pool_t *child_pool)
{
    apr_pool_t *parent_pool = apr_pool_parent_get(child_pool);

    if (parent_pool) {
        /* ideally this should be done by mp_xs_APR__Pool_2obj. Though
         * since most of the time we don't use custom pools, we don't
         * want the overhead of reading and writing pool's userdata in
         * the general case. therefore we do it here and in
         * mpxs_apr_pool_create. Though if there are any other
         * functions, that return perl objects whose guts include a
         * reference to a custom pool, they must do the ref-counting
         * as well.
         */
        mpxs_pool_account_t *data;
        apr_pool_userdata_get((void **)&data, MP_APR_POOL_NEW, parent_pool);
        if (data && data->sv) {
            MP_POOL_TRACE(MP_FUNC,
                          "parent pool (0x%lx) is a custom pool, sv 0x%lx",
                          (unsigned long)parent_pool,
                          (unsigned long)data->sv);

            return newRV_inc(data->sv);
        }
        else {
            MP_POOL_TRACE(MP_FUNC, "parent pool (0x%lx) is a core pool",
                          (unsigned long)parent_pool);
            return SvREFCNT_inc(mp_xs_APR__Pool_2obj(parent_pool));
        }
    }
    else {
        MP_POOL_TRACE(MP_FUNC, "pool (0x%lx) has no parents",
                      (unsigned long)child_pool);
                      return SvREFCNT_inc(mp_xs_APR__Pool_2obj(parent_pool));
    }
}

/**
 * destroy a pool
 * @param obj    an APR::Pool object
 */
static MP_INLINE void mpxs_apr_pool_DESTROY(pTHX_ SV *obj)
{
    apr_pool_t *p;
    SV *sv = SvRV(obj);

    /* MP_POOL_TRACE(MP_FUNC, "DESTROY 0x%lx-0x%lx",       */
    /*              (unsigned long)obj,(unsigned long)sv); */
    /* do_sv_dump(0, Perl_debug_log, obj, 0, 4, FALSE, 0); */

    p = mpxs_sv_object_deref(obj, apr_pool_t);
    if (!p) {
        /* non-custom pool */
        MP_POOL_TRACE(MP_FUNC, "skip apr_pool_destroy: not a custom pool");
        return;
    }

    if (sv && SvOK(sv)) {
        mpxs_pool_account_t *data;

        apr_pool_userdata_get((void **)&data, MP_APR_POOL_NEW, p);
        if (!(data && data->sv)) {
            MP_POOL_TRACE(MP_FUNC, "skip apr_pool_destroy: no sv found");
            return;
        }

        if (SvREFCNT(sv) == 1) {
            MP_POOL_TRACE(MP_FUNC, "call apr_pool_destroy: last reference");
            apr_pool_destroy(p);
        }
        else {
            /* when the pool object dies, sv's ref count decrements
             * itself automatically */
            MP_POOL_TRACE(MP_FUNC,
                          "skip apr_pool_destroy: refcount > 1 (%d)",
                          SvREFCNT(sv));
        }
    }
}

