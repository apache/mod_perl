#ifndef APR_PERLIO_H
#define APR_PERLIO_H

#ifdef PERLIO_LAYERS
#include "perliol.h"
#else 
#include "iperlsys.h"
#endif

#include "apr_portable.h"
#include "apr_file_io.h"
#include "apr_errno.h"

#ifndef MP_SOURCE_SCAN
#include "apr_optional.h"
#endif

/* 5.6.0 */
#ifndef IoTYPE_RDONLY
#define IoTYPE_RDONLY '<'
#endif
#ifndef IoTYPE_WRONLY
#define IoTYPE_WRONLY '>'
#endif

typedef enum {
    APR_PERLIO_HOOK_READ,
    APR_PERLIO_HOOK_WRITE
} apr_perlio_hook_e;

void apr_perlio_init(pTHX);

/* The following functions can be used from other .so libs, they just
 * need to load APR::PerlIO perl module first
 */
#ifndef MP_SOURCE_SCAN

#ifdef PERLIO_LAYERS
PerlIO *apr_perlio_apr_file_to_PerlIO(pTHX_ apr_file_t *file, apr_pool_t *pool,
                                      apr_perlio_hook_e type);
APR_DECLARE_OPTIONAL_FN(PerlIO *,
                        apr_perlio_apr_file_to_PerlIO,
                        (pTHX_ apr_file_t *file, apr_pool_t *pool,
                         apr_perlio_hook_e type));
#endif /* PERLIO_LAYERS */


SV *apr_perlio_apr_file_to_glob(pTHX_ apr_file_t *file, apr_pool_t *pool,
                                apr_perlio_hook_e type);
APR_DECLARE_OPTIONAL_FN(SV *,
                        apr_perlio_apr_file_to_glob,
                        (pTHX_ apr_file_t *file, apr_pool_t *pool,
                         apr_perlio_hook_e type));
#endif /* MP_SOURCE_SCAN */

#endif /* APR_PERLIO_H */
