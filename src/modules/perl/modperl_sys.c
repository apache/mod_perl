#include "modperl_largefiles.h"
#include "mod_perl.h"

/*
 * Stat_t needs flags in modperl_largefiles.h
 */
int modperl_sys_is_dir(pTHX_ SV *sv)
{
    Stat_t statbuf;
    STRLEN n_a;
    char *name = SvPV(sv, n_a);

    if (PerlLIO_stat(name, &statbuf) < 0) {
        return 0;
    }

    return S_ISDIR(statbuf.st_mode);
}

/*
 * Perl does not provide this abstraction.
 * APR does, but requires a pool.  efforts to expose this area of apr
 * failed.  so we roll our own.  *sigh*
 */
int modperl_sys_dlclose(void *handle)
{
#if defined(MP_SYS_DL_DLOPEN)
#ifdef I_DLFCN
#include <dlfcn.h>
#else
#include <nlist.h>
#include <link.h>
#endif
    return dlclose(handle) == 0;
#elif defined(MP_SYS_DL_DYLD)
    return NSUnLinkModule(handle, FALSE);
#elif defined(MP_SYS_DL_HPUX)
#include <dl.h>
    shl_unload((shl_t)handle);
    return 1;
#elif defined(MP_SYS_DL_WIN32)
    return FreeLibrary(handle);
#elif defined(MP_SYS_DL_BEOS)
    return unload_add_on(handle) < B_NO_ERROR;
#elif defined(MP_SYS_DL_DLLLOAD)
    return dllfree(handle) == 0;
#elif defined(MP_SYS_DL_AIX)
    return dlclose(handle) == 0;
#else
#error "modperl_sys_dlclose not defined on this platform"
    return 0;
#endif
}
