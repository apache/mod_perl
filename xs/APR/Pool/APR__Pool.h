#define MP_APR_POOL_NEW "APR::Pool::new"

/**
 * create a new pool or subpool
 * @param obj    an APR::Pool object or NULL
 * @return       a new pool or subpool
 */
static MP_INLINE apr_pool_t *mpxs_apr_pool_create(pTHX_ SV *obj)
{
    apr_pool_t *parent = mpxs_sv_object_deref(obj, apr_pool_t);
    apr_pool_t *newpool = NULL;
    (void)apr_pool_create(&newpool, parent);

    /* mark the pool as being created via APR::Pool->new()
     * see mpxs_apr_pool_DESTROY */
    apr_pool_userdata_set((const void *)1, MP_APR_POOL_NEW,
                          apr_pool_cleanup_null, newpool);

    return newpool;
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

/**
 * destroy a pool
 * @param obj    an APR::Pool object
 */
static MP_INLINE void mpxs_apr_pool_DESTROY(pTHX_ SV *obj) {

    void *flag;
    apr_pool_t *p;

    /* APR::Pool::DESTROY
     * we only want to call DESTROY on objects created by 
     * APR::Pool->new(), not objects representing native pools
     * like r->pool.  native pools can be destroyed using 
     * apr_pool_destroy ($p->destroy) */

    p = mpxs_sv_object_deref(obj, apr_pool_t);

    apr_pool_userdata_get(&flag, MP_APR_POOL_NEW, p);

    if (flag) {
         apr_pool_destroy(p);
    }
}
