#define apr_pool_DESTROY(p) apr_pool_destroy(p)

static MP_INLINE apr_pool_t *mpxs_apr_pool_create(pTHX_ SV *obj)
{
    apr_pool_t *parent = mpxs_sv_object_deref(obj, apr_pool_t);
    apr_pool_t *retval = NULL;
    (void)apr_pool_create(&retval, parent);
    return retval;
}

/* XXX: need to properly deal with PerlInterpScope */

typedef struct {
    SV *cv;
    SV *arg;
    apr_pool_t *p;
    PerlInterpreter *perl;
} mpxs_cleanup_t;

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

    return status;
}

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
#endif

    apr_pool_cleanup_register(p, data,
                              mpxs_cleanup_run,
                              apr_pool_cleanup_null);
}
