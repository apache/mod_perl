#ifndef MODPERL_TYPES_H
#define MODPERL_TYPES_H

#ifdef AP_IOBUFSIZE
#   define MP_IOBUFSIZE AP_IOBUFSIZE
#else
#   define MP_IOBUFSIZE 8192
#endif

/* aliases */

typedef apr_array_header_t MpAV;
typedef apr_table_t        MpHV;

/* mod_perl structures */

typedef struct {
    request_rec *r;
    conn_rec    *c;
    server_rec  *s;
} modperl_rcs_t;

#ifdef USE_ITHREADS

typedef struct modperl_list_t modperl_list_t;

struct modperl_list_t {
    modperl_list_t *prev, *next;
    void *data;
};

typedef struct modperl_interp_t modperl_interp_t;
typedef struct modperl_interp_pool_t modperl_interp_pool_t;
typedef struct modperl_tipool_t modperl_tipool_t;

struct modperl_interp_t {
    modperl_interp_pool_t *mip;
    PerlInterpreter *perl;
    int num_requests;
    U8 flags;
#ifdef MP_TRACE
    unsigned long tid;
#endif
};

typedef struct {
    /* s == startup grow
     * r == runtime grow
     */
    void * (*tipool_sgrow)(modperl_tipool_t *tipool, void *data);
    void * (*tipool_rgrow)(modperl_tipool_t *tipool, void *data);
    void (*tipool_shrink)(modperl_tipool_t *tipool, void *data,
                          void *item);
    void (*tipool_destroy)(modperl_tipool_t *tipool, void *data,
                           void *item);
    void (*tipool_dump)(modperl_tipool_t *tipool, void *data,
                        modperl_list_t *listp);
} modperl_tipool_vtbl_t;

typedef struct {
    int start; /* number of items to create at startup */
    int min_spare; /* minimum number of spare items */
    int max_spare; /* maximum number of spare items */
    int max; /* maximum number of items */
    int max_requests; /* maximum number of requests per item */
} modperl_tipool_config_t;

struct modperl_tipool_t {
    perl_mutex tiplock;
    perl_cond available;
    apr_pool_t *ap_pool;
    modperl_list_t *idle, *busy;
    int in_use; /* number of items currrently in use */
    int size; /* current number of items */
    void *data; /* user data */
    modperl_tipool_config_t *cfg;
    modperl_tipool_vtbl_t *func;
};

struct modperl_interp_pool_t {
    apr_pool_t *ap_pool;
    server_rec *server;
    modperl_tipool_t *tipool;
    modperl_tipool_config_t *tipool_cfg;
    modperl_interp_t *parent; /* from which to perl_clone() */
};

#endif /* USE_ITHREADS */

typedef U32 modperl_opts_t;

typedef struct {
    modperl_opts_t opts;
    modperl_opts_t opts_add;
    modperl_opts_t opts_remove;
    modperl_opts_t opts_override;
    int unset;
} modperl_options_t;

typedef enum {
    MP_INTERP_LIFETIME_UNDEF,
    MP_INTERP_LIFETIME_HANDLER,
    MP_INTERP_LIFETIME_SUBREQUEST,
    MP_INTERP_LIFETIME_REQUEST,
    MP_INTERP_LIFETIME_CONNECTION,
} modperl_interp_lifetime_e;

typedef struct {
    MpHV *SetVars;
    MpAV *PassEnv;
    MpAV *PerlRequire, *PerlModule;
    MpAV *handlers_per_srv[MP_HANDLER_NUM_PER_SRV];
    MpAV *handlers_files[MP_HANDLER_NUM_FILES];
    MpAV *handlers_process[MP_HANDLER_NUM_PROCESS];
    MpAV *handlers_connection[MP_HANDLER_NUM_CONNECTION];
#ifdef USE_ITHREADS
    modperl_interp_pool_t *mip;
    modperl_tipool_config_t *interp_pool_cfg;
    modperl_interp_lifetime_e interp_lifetime;
    int threaded_mpm;
#else
    PerlInterpreter *perl;
#endif
#ifdef MP_USE_GTOP
    modperl_gtop_t *gtop;
#endif
    MpAV *argv;
    modperl_options_t *flags;
} modperl_config_srv_t;

typedef struct {
    char *location;
    char *PerlDispatchHandler;
    MpAV *handlers_per_dir[MP_HANDLER_NUM_PER_DIR];
    MpHV *SetEnv;
    MpHV *SetVars;
    U8 flags;
#ifdef USE_ITHREADS
    modperl_interp_lifetime_e interp_lifetime;
#endif
} modperl_config_dir_t;

typedef struct modperl_mgv_t modperl_mgv_t;

struct modperl_mgv_t {
    char *name;
    int len;
    UV hash;
    modperl_mgv_t *next;
};

typedef struct {
    modperl_mgv_t *mgv_obj;
    modperl_mgv_t *mgv_cv;
    const char *name; /* orignal name from .conf if any */
    U8 flags;
} modperl_handler_t;

#define MP_HANDLER_TYPE_CHAR 1
#define MP_HANDLER_TYPE_SV   2

typedef struct {
    int outcnt;
    char outbuf[MP_IOBUFSIZE];
    apr_pool_t *pool;
    ap_filter_t *filters;
} modperl_wbucket_t;

typedef enum {
    MP_INPUT_FILTER_MODE,
    MP_OUTPUT_FILTER_MODE,
} modperl_filter_mode_e;

typedef struct {
    int eos;
    ap_filter_t *f;
    char *leftover;
    apr_ssize_t remaining;
    modperl_wbucket_t wbucket;
    apr_bucket *bucket;
    apr_bucket_brigade *bb;
    apr_status_t rc;
    modperl_filter_mode_e mode;
    apr_pool_t *pool;
} modperl_filter_t;

typedef modperl_filter_t *  Apache__OutputFilter;
typedef modperl_filter_t *  Apache__InputFilter;

typedef struct {
    SV *data;
    modperl_handler_t *handler;
    PerlInterpreter *perl;
} modperl_filter_ctx_t;

typedef struct {
    HV *pnotes;
    modperl_wbucket_t wbucket;
} modperl_config_req_t;

#endif /* MODPERL_TYPES_H */
