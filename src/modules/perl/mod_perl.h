#ifndef MOD_PERL_H
#define MOD_PERL_H

#include "modperl_apache_includes.h"
#include "modperl_perl_includes.h"
#include "modperl_apache_compat.h"

#ifdef WIN32
#define MP_THREADED 1
#else
#define MP_THREADED (defined(USE_ITHREADS) && APR_HAS_THREADS)
#endif

extern module AP_MODULE_DECLARE_DATA perl_module;

#include "modperl_flags.h"
#include "modperl_hooks.h"
#include "modperl_perl_global.h"
#include "modperl_perl_pp.h"
#include "modperl_sys.h"
#include "modperl_const.h"
#include "modperl_constants.h"

/* both perl and apr have largefile support enabled */
#define MP_LARGE_FILES_ENABLED \
   (defined(USE_LARGE_FILES) && APR_HAS_LARGE_FILES)

/* both perl and apr have largefile support disabled */
#define MP_LARGE_FILES_DISABLED \
   (!defined(USE_LARGE_FILES) && !APR_HAS_LARGE_FILES)

/* perl support is enabled, apr support is disabled */
#define MP_LARGE_FILES_PERL_ONLY \
   (defined(USE_LARGE_FILES) && !APR_HAS_LARGE_FILES)

/* apr support is enabled, perl support is disabled */
#define MP_LARGE_FILES_APR_ONLY \
   (!defined(USE_LARGE_FILES) && APR_HAS_LARGE_FILES)

/* conflict due to not have either both perl and apr
 * support enabled or both disabled
 */
#define MP_LARGE_FILES_CONFLICT \
   !(MP_LARGE_FILES_ENABLED || MP_LARGE_FILES_DISABLED)

#ifdef MP_USE_GTOP
#include "modperl_gtop.h"
#endif
#include "modperl_time.h"
#include "modperl_types.h"
#include "modperl_util.h"
#include "modperl_config.h"
#include "modperl_cmd.h"
#include "modperl_handler.h"
#include "modperl_callback.h"
#include "modperl_tipool.h"
#include "modperl_interp.h"
#include "modperl_log.h"
#include "modperl_options.h"
#include "modperl_directives.h"
#include "modperl_io.h"
#include "modperl_filter.h"
#include "modperl_bucket.h"
#include "modperl_pcw.h"
#include "modperl_mgv.h"
#include "modperl_global.h"
#include "modperl_env.h"
#include "modperl_cgi.h"
#include "modperl_perl.h"
#include "modperl_svptr_table.h"
#include "modperl_module.h"

int modperl_init_vhost(server_rec *s, apr_pool_t *p,
                       server_rec *base_server);
void modperl_init(server_rec *s, apr_pool_t *p);
void modperl_init_globals(server_rec *s, apr_pool_t *pconf);
int modperl_run(void);
int modperl_is_running(void);
int modperl_hook_init(apr_pool_t *pconf, apr_pool_t *plog, 
                      apr_pool_t *ptemp, server_rec *s);
int modperl_hook_pre_config(apr_pool_t *p, apr_pool_t *plog,
                            apr_pool_t *ptemp);
void modperl_register_hooks(apr_pool_t *p);
apr_pool_t *modperl_server_pool(void);
PerlInterpreter *modperl_startup(server_rec *s, apr_pool_t *p);
int modperl_perl_destruct_level(void);
void xs_init(pTHX);

void modperl_response_init(request_rec *r);
apr_status_t modperl_response_finish(request_rec *r);
int modperl_response_handler(request_rec *r);
int modperl_response_handler_cgi(request_rec *r);

/* betting on Perl*Handlers not using CvXSUBANY
 * mod_perl reuses this field for handler attributes
 */
#define MP_CODE_ATTRS(cv) (CvXSUBANY((CV*)cv).any_i32)

#define MgTypeExt(mg) (mg->mg_type == '~')

typedef void MP_FUNC_T(modperl_table_modify_t) (apr_table_t *,
                                                const char *,
                                                const char *);

#endif /*  MOD_PERL_H */
