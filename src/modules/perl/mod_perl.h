#ifndef MOD_PERL_H
#define MOD_PERL_H

#include "modperl_apache_includes.h"
#include "modperl_perl_includes.h"

#define MP_THREADED (defined(USE_ITHREADS) && APR_HAS_THREADS)

extern module AP_MODULE_DECLARE_DATA perl_module;

#include "modperl_flags.h"
#include "modperl_hooks.h"

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

void modperl_init(server_rec *s, apr_pool_t *p);
void modperl_hook_init(apr_pool_t *pconf, apr_pool_t *plog, 
                       apr_pool_t *ptemp, server_rec *s);
void modperl_pre_config_handler(apr_pool_t *p, apr_pool_t *plog,
                                apr_pool_t *ptemp);
void modperl_register_hooks(apr_pool_t *p);
PerlInterpreter *modperl_startup(server_rec *s, apr_pool_t *p);
void xs_init(pTHXo);

void modperl_response_init(request_rec *r);
void modperl_response_finish(request_rec *r);
int modperl_response_handler(request_rec *r);
int modperl_response_handler_cgi(request_rec *r);

/* betting on Perl*Handlers not using CvXSUBANY
 * mod_perl reuses this field for handler attributes
 */
#define MP_CODE_ATTRS(cv) (CvXSUBANY((CV*)cv).any_i32)

#define MgTypeExt(mg) (mg->mg_type == '~')

#endif /*  MOD_PERL_H */
