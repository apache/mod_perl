#ifndef MODPERL_IO_APACHE_H
#define MODPERL_IO_APACHE_H

#ifdef PERLIO_LAYERS

#include "perliol.h"
/* XXX: should this be a Makefile.PL config option? */
#define MP_IO_TIE_PERLIO

#include "apr_portable.h"
#include "apr_file_io.h"
#include "apr_errno.h"

typedef enum {
    MODPERL_IO_APACHE_HOOK_READ,
    MODPERL_IO_APACHE_HOOK_WRITE
} modperl_io_apache_hook_e;

#define PERLIO_Apache_DEBUG

MP_INLINE void modperl_io_apache_init(pTHX);

#else /* #ifdef PERLIO_LAYERS */

#define modperl_io_apache_init(pTHX)

#endif /* #ifdef PERLIO_LAYERS */
    
#endif /* MODPERL_IO_APACHE_H */
