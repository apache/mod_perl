#include "mod_perl.h"

#if ((PERL_REVISION == 5) && (PERL_VERSION >= 7))
#   define TIEHANDLE_SV(handle) (SV*)GvIOp((SV*)handle)
#else
#   define TIEHANDLE_SV(handle) (SV*)handle
#endif

#define dHANDLE(name) GV *handle = gv_fetchpv(name, TRUE, SVt_PVIO)

#define TIEHANDLE(handle,r) \
modperl_io_handle_tie(aTHX_ handle, "Apache::RequestRec", (void *)r)

#define TIED(handle) \
modperl_io_handle_tied(aTHX_ handle, "Apache::RequestRec")

/*
 * XXX: bleedperl change #11639 switch tied handle magic
 * from living in the gv to the GvIOp(gv), so we have to deal
 * with both to support 5.6.x
 */
MP_INLINE void modperl_io_handle_untie(pTHX_ GV *handle)
{
#ifdef MP_TRACE
    if (mg_find(TIEHANDLE_SV(handle), 'q')) {
        MP_TRACE_g(MP_FUNC, "untie *%s(0x%lx), REFCNT=%d\n",
                   GvNAME(handle), (unsigned long)handle,
                   SvREFCNT(TIEHANDLE_SV(handle)));
    }
    else {
        return;
    }
#endif

    sv_unmagic(TIEHANDLE_SV(handle), 'q');
}

MP_INLINE void modperl_io_handle_tie(pTHX_ GV *handle,
                                     char *classname, void *ptr)
{
    SV *obj = modperl_ptr2obj(aTHX_ classname, ptr);

    modperl_io_handle_untie(aTHX_ handle);

    sv_magic(TIEHANDLE_SV(handle), obj, 'q', Nullch, 0);

    SvREFCNT_dec(obj); /* since sv_magic did SvREFCNT_inc */

    MP_TRACE_g(MP_FUNC, "tie *%s(0x%lx) => %s, REFCNT=%d\n",
               GvNAME(handle), (unsigned long)handle, classname,
               SvREFCNT(TIEHANDLE_SV(handle)));
}

MP_INLINE int modperl_io_handle_tied(pTHX_ GV *handle, char *classname)
{
    MAGIC *mg;
    SV *sv = TIEHANDLE_SV(handle);

    if (SvMAGICAL(sv) && (mg = mg_find(sv, 'q'))) {
	char *package = HvNAME(SvSTASH((SV*)SvRV(mg->mg_obj)));

	if (!strEQ(package, classname)) {
	    MP_TRACE_g(MP_FUNC, "%s tied to %s\n", GvNAME(handle), package);
	    return TRUE;
	}
    }

    return FALSE;
}

MP_INLINE GV *modperl_io_tie_stdout(pTHX_ request_rec *r)
{
#if defined(MP_IO_TIE_SFIO)
    /* XXX */
#elif defined(MP_IO_TIE_PERLIO)
    /* XXX */
#else
    dHANDLE("STDOUT");

    if (TIED(handle)) {
        return handle;
    }

    IoFLUSH_off(PL_defoutgv); /* $|=0 */

    TIEHANDLE(handle, r);

    return handle;
#endif
}

MP_INLINE GV *modperl_io_tie_stdin(pTHX_ request_rec *r)
{
#if defined(MP_IO_TIE_SFIO)
    /* XXX */
#elif defined(MP_IO_TIE_PERLIO)
    /* XXX */
#else
    dHANDLE("STDIN");

    if (TIED(handle)) {
        return handle;
    }

    TIEHANDLE(handle, r);

    return handle;
#endif
}
