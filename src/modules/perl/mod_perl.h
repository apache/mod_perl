#ifndef MOD_PERL_H
#define MOD_PERL_H

#ifndef PERL_NO_GET_CONTEXT
#define PERL_NO_GET_CONTEXT
#endif

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#undef dNOOP
#define dNOOP extern int __attribute__ ((unused)) Perl___notused

#include "ap_mmn.h"
#include "httpd.h"
#include "http_config.h"
#include "http_log.h"
#include "http_protocol.h"
#include "http_main.h"
#include "http_request.h"
#include "http_connection.h"

#include "apr_lock.h"

extern module MODULE_VAR_EXPORT perl_module;

#include "modperl_flags.h"
#include "modperl_hooks.h"

#ifdef MP_USE_GTOP
#include "modperl_gtop.h"
#endif
#include "modperl_types.h"
#include "modperl_config.h"
#include "modperl_callback.h"
#include "modperl_interp.h"
#include "modperl_log.h"

#include "modperl_directives.h"

void modperl_init(server_rec *s, ap_pool_t *p);
void xs_init(pTHXo);

#endif /*  MOD_PERL_H */
