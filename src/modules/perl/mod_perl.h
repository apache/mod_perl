#ifndef MOD_PERL_H
#define MOD_PERL_H

#include "modperl_apache_includes.h"
#include "modperl_perl_includes.h"

extern module MODULE_VAR_EXPORT perl_module;

#include "modperl_flags.h"
#include "modperl_hooks.h"

#ifdef MP_USE_GTOP
#include "modperl_gtop.h"
#endif
#include "modperl_types.h"
#include "modperl_util.h"
#include "modperl_config.h"
#include "modperl_callback.h"
#include "modperl_tipool.h"
#include "modperl_interp.h"
#include "modperl_log.h"
#include "modperl_options.h"
#include "modperl_directives.h"
#include "modperl_filter.h"

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

#endif /*  MOD_PERL_H */
