#define MP_APR_POOL_NEW "APR::Pool::new"

typedef struct {
    int destroyable;
    int ref_count;
} mpxs_pool_account_t;

/* XXX: should we make it a new global tracing category
 * MOD_PERL_TRACE=p for tracing pool management? */
#define MP_POOL_TRACE_DO 0

#if MP_POOL_TRACE_DO && defined(MP_TRACE)
#define MP_POOL_TRACE modperl_trace
#else
#define MP_POOL_TRACE if (0) modperl_trace
#endif


static MP_INLINE int mpxs_apr_pool_ref_count_inc(apr_pool_t *p)
{
    mpxs_pool_account_t *data;
    
    apr_pool_userdata_get((void **)&data, MP_APR_POOL_NEW, p);
    if (!data) {
        data = (mpxs_pool_account_t *)apr_pcalloc(p, sizeof(*data));
    }

    data->ref_count++;

    apr_pool_userdata_set(data, MP_APR_POOL_NEW, NULL, p);

    return data->ref_count;
}

static MP_INLINE int mpxs_apr_pool_ref_count_dec(apr_pool_t *p)
{
    mpxs_pool_account_t *data;

    apr_pool_userdata_get((void **)&data, MP_APR_POOL_NEW, p);
    if (!data) {
        /* if there is no data, there is nothing to decrement */
        return 0;
    }

    if (data->ref_count > 0) {
        data->ref_count--;
    }
    
    apr_pool_userdata_set(data, MP_APR_POOL_NEW, NULL, p);

    return data->ref_count;
}

static MP_INLINE void mpxs_apr_pool_destroyable_set(apr_pool_t *p)
{
    mpxs_pool_account_t *data;
    
    apr_pool_userdata_get((void **)&data, MP_APR_POOL_NEW, p);
    if (!data) {
        data = (mpxs_pool_account_t *)apr_pcalloc(p, sizeof(*data));
    }

    data->destroyable++;

    apr_pool_userdata_set(data, MP_APR_POOL_NEW, NULL, p);
}

static MP_INLINE void mpxs_apr_pool_destroyable_unset(apr_pool_t *p)
{
    mpxs_pool_account_t *data;
    
    apr_pool_userdata_get((void **)&data, MP_APR_POOL_NEW, p);
    if (!data) {
        /* if there is no data, there is nothing to unset */
        return;
    }

    data->destroyable = 0;

    apr_pool_userdata_set(data, MP_APR_POOL_NEW, NULL, p);
}

static MP_INLINE int mpxs_apr_pool_is_pool_destroyable(apr_pool_t *p)
{
    mpxs_pool_account_t *data;

    apr_pool_userdata_get((void **)&data, MP_APR_POOL_NEW, p);
    if (!data) {
        /* pools with no special data weren't created by us and
         * therefore shouldn't be destroyed */
        return 0;
    }

    return data->destroyable && !data->ref_count;
}

static MP_INLINE apr_status_t
mpxs_apr_pool_cleanup_destroyable_unset(void *data)
{
    /* unset the flag for the key MP_APR_POOL_NEW to prevent from
     * apr_pool_destroy being called twice */
    mpxs_apr_pool_destroyable_unset((apr_pool_t *)data);
    
    return APR_SUCCESS;
}

/**
 * Create a new pool or subpool.
 * @param  parent_pool_obj   an APR::Pool object or an "APR::Pool" class
 * @return                   a new pool or subpool
 */
static MP_INLINE apr_pool_t *mpxs_apr_pool_create(pTHX_ SV *parent_pool_obj)
{
    apr_pool_t *parent_pool = mpxs_sv_object_deref(parent_pool_obj, apr_pool_t);
    apr_pool_t *child_pool  = NULL;
    
    (void)apr_pool_create(&child_pool, parent_pool);
    MP_POOL_TRACE(MP_FUNC, "new pool 0x%lx\n", child_pool);

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

    /* mark the pool eligible for destruction. We aren't suppose to
     * destroy pools not created by APR::Pool::new().
     * see mpxs_apr_pool_DESTROY
     */
    mpxs_apr_pool_destroyable_set(child_pool);

    /* Each newly created pool must be destroyed only once. Calling
     * apr_pool_destroy will destroy the pool and its children pools,
     * however a perl object for a sub-pool will still keep a pointer
     * to the pool which was already destroyed. When this object is
     * DESTROYed, apr_pool_destroy will be called again. In the best
     * case it'll try to destroy a non-existing pool, but in the worst
     * case it'll destroy a different valid pool which has been given
     * the same memory allocation wrecking havoc. Therefore we must
     * ensure that when sub-pools are destroyed via the parent pool,
     * their cleanup callbacks will destroy their perl objects
     */
    apr_pool_cleanup_register(child_pool, (void *)child_pool,
                              mpxs_apr_pool_cleanup_destroyable_unset,
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

    mpxs_apr_pool_ref_count_inc(child_pool);
    return child_pool;
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


static MP_INLINE apr_pool_t *
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
        mpxs_apr_pool_ref_count_inc(parent_pool);
    }
    
    return parent_pool;
}
    
/**
 * destroy a pool
 * @param obj    an APR::Pool object
 */
static MP_INLINE void mpxs_apr_pool_DESTROY(pTHX_ SV *obj) {

    apr_pool_t *p;

    p = mpxs_sv_object_deref(obj, apr_pool_t);

    mpxs_apr_pool_ref_count_dec(p);
    
    /* APR::Pool::DESTROY
     * we only want to call DESTROY on objects created by 
     * APR::Pool->new(), not objects representing native pools
     * like r->pool.  native pools can be destroyed using 
     * apr_pool_destroy ($p->destroy)
     */
    if (mpxs_apr_pool_is_pool_destroyable(p)) {
        MP_POOL_TRACE(MP_FUNC, "DESTROY pool 0x%lx\n", (unsigned long)p);
        apr_pool_destroy(p);
        /* mpxs_apr_pool_cleanup_destroyable_unset called by
         * apr_pool_destroy takes care of marking this pool as
         * undestroyable, so we do it only once */
    }
    else {
        /* either because we didn't create this pool (e.g., r->pool),
         * or because this pool has already been destroyed via the
         * destruction of the parent pool
         */
        MP_POOL_TRACE(MP_FUNC, "skipping DESTROY, "
                  "this object is not eligible to destroy pool 0x%lx\n",
                  (unsigned long)p);
        
    }
}
