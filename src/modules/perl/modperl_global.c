#include "mod_perl.h"

void modperl_global_request_cfg_set(request_rec *r)
{
    MP_dDCFG;
    MP_dRCFG;

    /* only if PerlOptions +GlobalRequest and not done already */
    if (MpDirGLOBAL_REQUEST(dcfg) && !MpReqSET_GLOBAL_REQUEST(rcfg)) {
        modperl_global_request_set(r);
        MpReqSET_GLOBAL_REQUEST_On(rcfg);
    }
}

void modperl_global_request_set(request_rec *r)
{
    MP_dRCFG;

    modperl_tls_set_request_rec(r);

    /* so 'PerlOptions +GlobalRequest' doesnt wipe us out */
    MpReqSET_GLOBAL_REQUEST_On(rcfg);

    if (r->main) {
        /* reset after subrequests */
        modperl_tls_reset_cleanup_request_rec(r->pool, r->main);
    }
}

void modperl_global_request_obj_set(pTHX_ SV *svr)
{
    /* XXX: support sublassing */
    request_rec *r = modperl_sv2request_rec(aTHX_ svr);
    modperl_global_request_set(r);
}

#if MP_THREADED
static apr_status_t modperl_global_cleanup(void *data)
{
    modperl_global_t *global = (modperl_global_t *)data;

    MP_TRACE_g(MP_FUNC, "destroy lock for %s\n", global->name);
    MUTEX_DESTROY(&global->glock);

    return APR_SUCCESS;
}
#endif

void modperl_global_init(modperl_global_t *global, apr_pool_t *p,
                         void *data, const char *name)
{
    Zero(global, 1, modperl_global_t);

    global->data = data;
    global->name = name;

#if MP_THREADED
    MUTEX_INIT(&global->glock);

    apr_pool_cleanup_register(p, (void *)global,
                              modperl_global_cleanup,
                              apr_pool_cleanup_null);
#endif

    MP_TRACE_g(MP_FUNC, "init %s\n", name);
}

void modperl_global_lock(modperl_global_t *global)
{
#if MP_THREADED
    MP_TRACE_g(MP_FUNC, "locking %s\n", global->name);
    MUTEX_LOCK(&global->glock);
#endif
}

void modperl_global_unlock(modperl_global_t *global)
{
#if MP_THREADED
    MP_TRACE_g(MP_FUNC, "unlocking %s\n", global->name);
    MUTEX_UNLOCK(&global->glock);
#endif
}

void *modperl_global_get(modperl_global_t *global)
{
    return global->data;
}

void modperl_global_set(modperl_global_t *global, void *data)
{
    global->data = data;
}

/* hopefully there wont be many of these */

#define MP_GLOBAL_IMPL(gname, type)                      \
                                                         \
static modperl_global_t MP_global_##gname;               \
                                                         \
void modperl_global_init_##gname(apr_pool_t *p,          \
                                 type gname)             \
{                                                        \
    modperl_global_init(&MP_global_##gname, p,           \
                        (void *)gname, #gname);          \
}                                                        \
                                                         \
void modperl_global_lock_##gname(void)                   \
{                                                        \
    modperl_global_lock(&MP_global_##gname);             \
}                                                        \
                                                         \
void modperl_global_unlock_##gname(void)                 \
{                                                        \
    modperl_global_unlock(&MP_global_##gname);           \
}                                                        \
                                                         \
type modperl_global_get_##gname(void)                    \
{                                                        \
    return (type )                                       \
       modperl_global_get(&MP_global_##gname);           \
}                                                        \
                                                         \
void modperl_global_set_##gname(void *data)              \
{                                                        \
    modperl_global_set(&MP_global_##gname, data);        \
}                                                        \

MP_GLOBAL_IMPL(pconf, apr_pool_t *);
MP_GLOBAL_IMPL(server_rec, server_rec *);
MP_GLOBAL_IMPL(threaded_mpm, int);

#if MP_THREADED
static apr_status_t modperl_tls_cleanup(void *data)
{
    return apr_threadkey_private_delete((apr_threadkey_t *)data);
}
#endif

apr_status_t modperl_tls_create(apr_pool_t *p, modperl_tls_t **key)
{
#if MP_THREADED
    apr_status_t status = apr_threadkey_private_create(key, NULL, p);
    apr_pool_cleanup_register(p, (void *)*key,
                              modperl_tls_cleanup,
                              apr_pool_cleanup_null);
    return status;
#else
    *key = apr_pcalloc(p, sizeof(**key));
    return APR_SUCCESS;
#endif
}

apr_status_t modperl_tls_get(modperl_tls_t *key, void **data)
{
#if MP_THREADED
    if (!key) {
        *data = NULL;
        return APR_SUCCESS;
    }
    return apr_threadkey_private_get(data, key);
#else
    *data = modperl_global_get((modperl_global_t *)key);
    return APR_SUCCESS;
#endif
}

apr_status_t modperl_tls_set(modperl_tls_t *key, void *data)
{
#if MP_THREADED
    return apr_threadkey_private_set(data, key);
#else
    modperl_global_set((modperl_global_t *)key, data);
    return APR_SUCCESS;
#endif
}

typedef struct {
    modperl_tls_t *key;
    void *data;
} modperl_tls_cleanup_data_t;

static apr_status_t modperl_tls_reset(void *data)
{
    modperl_tls_cleanup_data_t *cdata;
    return modperl_tls_set(cdata->key, data);
}

void modperl_tls_reset_cleanup(apr_pool_t *p, modperl_tls_t *key,
                               void *data)
{
    modperl_tls_cleanup_data_t *cdata =
        (modperl_tls_cleanup_data_t *)apr_pcalloc(p, sizeof(*cdata));

    apr_pool_cleanup_register(p, (void *)cdata,
                              modperl_tls_reset,
                              apr_pool_cleanup_null);
}

/* hopefully there wont be many of these either */

#define MP_TLS_IMPL(gname, type)                         \
                                                         \
static modperl_tls_t *MP_tls_##gname;                    \
                                                         \
apr_status_t                                             \
modperl_tls_create_##gname(apr_pool_t *p)                \
{                                                        \
    return modperl_tls_create(p, &MP_tls_##gname);       \
}                                                        \
                                                         \
apr_status_t modperl_tls_get_##gname(type *data)         \
{                                                        \
    void *ptr;                                           \
    apr_status_t status =                                \
        modperl_tls_get(MP_tls_##gname, &ptr);           \
    *data = (type )ptr;                                  \
    return status;                                       \
}                                                        \
                                                         \
apr_status_t modperl_tls_set_##gname(void *data)         \
{                                                        \
    return modperl_tls_set(MP_tls_##gname, data);        \
}                                                        \
                                                         \
void modperl_tls_reset_cleanup_##gname(apr_pool_t *p,    \
                                       type data)        \
{                                                        \
    modperl_tls_reset_cleanup(p, MP_tls_##gname,         \
                              (void *)data);             \
}

MP_TLS_IMPL(request_rec, request_rec *);
