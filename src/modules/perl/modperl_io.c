#include "mod_perl.h"

#define TIEHANDLE(handle,r) \
modperl_io_handle_tie(aTHX_ handle, "Apache::RequestRec", (void *)r)

#define TIED(handle) \
modperl_io_handle_tied(aTHX_ handle, "Apache::RequestRec")

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

MP_INLINE GV *modperl_io_tie_stdin(pTHX_ request_rec *r)
{
#if defined(MP_IO_TIE_SFIO)
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

MP_INLINE GV *modperl_io_tie_stdout(pTHX_ request_rec *r)
{
#if defined(MP_IO_TIE_SFIO)
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

MP_INLINE void modperl_io_handle_untie(pTHX_ GV *handle)
{
#ifdef MP_TRACE
    if (mg_find(TIEHANDLE_SV(handle), 'q')) {
        MP_TRACE_g(MP_FUNC, "untie *%s(0x%lx), REFCNT=%d\n",
                   GvNAME(handle), (unsigned long)handle,
                   SvREFCNT(TIEHANDLE_SV(handle)));
    }
#endif

    sv_unmagic(TIEHANDLE_SV(handle), 'q');
}

MP_INLINE GV *modperl_io_perlio_override_stdin(pTHX_ request_rec *r)
{
    dHANDLE("STDIN");
    int status;
    GV *handle_save = gv_fetchpv(Perl_form(aTHX_ "Apache::RequestIO::_GEN_%ld",
                                           (long)PL_gensym++),
                                 TRUE, SVt_PVIO);
    SV *sv = sv_newmortal();

    sv_setref_pv(sv, "Apache::RequestRec", (void*)r);
    MP_TRACE_o(MP_FUNC, "start");

    /* open my $oldout, "<&STDIN" or die "Can't dup STDIN: $!"; */
    status = Perl_do_open(aTHX_ handle_save, "<&STDIN", 7, FALSE, O_RDONLY,
                          0, Nullfp);
    if (status == 0) {
        Perl_croak(aTHX_ "Failed to dup STDIN: %_", get_sv("!", TRUE));
    }

    /* similar to PerlIO::scalar, the PerlIO::Apache layer doesn't
     * have file descriptors, so STDIN must be closed before it can
     * be reopened */
    Perl_do_close(aTHX_ handle, TRUE); 
    status = Perl_do_open9(aTHX_ handle, "<:Apache", 8, FALSE, O_RDONLY,
                           0, Nullfp, sv, 1);
    if (status == 0) {
        Perl_croak(aTHX_ "Failed to open STDIN: %_", get_sv("!", TRUE));
    }

    MP_TRACE_o(MP_FUNC, "end\n");

    return handle_save;
}

/* XXX: refactor to merge with the previous function */
MP_INLINE GV *modperl_io_perlio_override_stdout(pTHX_ request_rec *r)
{
    dHANDLE("STDOUT");
    int status;
    GV *handle_save = gv_fetchpv(Perl_form(aTHX_ "Apache::RequestIO::_GEN_%ld",
                                           (long)PL_gensym++),
                                 TRUE, SVt_PVIO);
    SV *sv = sv_newmortal();

    MP_TRACE_o(MP_FUNC, "start");

    sv_setref_pv(sv, "Apache::RequestRec", (void*)r);

    /* open my $oldout, ">&STDOUT" or die "Can't dup STDOUT: $!"; */
    status = Perl_do_open(aTHX_ handle_save, ">&STDOUT", 8, FALSE, O_WRONLY,
                          0, Nullfp);
    if (status == 0) {
        Perl_croak(aTHX_ "Failed to dup STDOUT: %_", get_sv("!", TRUE));
    }

    /* similar to PerlIO::scalar, the PerlIO::Apache layer doesn't
     * have file descriptors, so STDOUT must be closed before it can
     * be reopened */
    Perl_do_close(aTHX_ handle, TRUE); 
    status = Perl_do_open9(aTHX_ handle, ">:Apache", 8, FALSE, O_WRONLY,
                           0, Nullfp, sv, 1);
    if (status == 0) {
        Perl_croak(aTHX_ "Failed to open STDOUT: %_", get_sv("!", TRUE));
    }

    MP_TRACE_o(MP_FUNC, "end\n");

    /* XXX: shouldn't we preserve the value STDOUT had before it was
     * overridden? */
    IoFLUSH_off(handle); /* STDOUT's $|=0 */

    return handle_save;
    
}

MP_INLINE void modperl_io_perlio_restore_stdin(pTHX_ GV *handle)
{
    GV *handle_orig = gv_fetchpv("STDIN", FALSE, SVt_PVIO);
    int status;

    MP_TRACE_o(MP_FUNC, "start");

    /* Perl_do_close(aTHX_ handle_orig, FALSE); */

    /* open STDIN, "<&STDIN_SAVED" or die "Can't dup STDIN_SAVED: $!"; */
    status = Perl_do_open9(aTHX_ handle_orig, "<&", 2, FALSE, O_RDONLY,
                           0, Nullfp, (SV*)handle, 1);
    Perl_do_close(aTHX_ handle, FALSE);
    (void)hv_delete(gv_stashpv("Apache::RequestIO", TRUE), 
		    GvNAME(handle), GvNAMELEN(handle), G_DISCARD);
    if (status == 0) {
        Perl_croak(aTHX_ "Failed to restore STDIN: %_", get_sv("!", TRUE));
    }

    MP_TRACE_o(MP_FUNC, "end\n");
}

MP_INLINE void modperl_io_perlio_restore_stdout(pTHX_ GV *handle)
{ 
    GV *handle_orig = gv_fetchpv("STDOUT", FALSE, SVt_PVIO);
    int status;

    MP_TRACE_o(MP_FUNC, "start");

    /* since closing unflushed STDOUT may trigger a subrequest
     * (e.g. via mod_include), resulting in potential another response
     * handler call, which may try to close STDOUT too. We will
     * segfault, if that subrequest doesn't return before the the top
     * level STDOUT is attempted to be closed. To prevent this
     * situation always explicitly flush STDOUT, before reopening it.
     */
    if (GvIOn(handle_orig) && IoOFP(GvIOn(handle_orig))) {
        PerlIO_flush(IoOFP(GvIOn(handle_orig)));
    }
    /* open STDOUT, ">&STDOUT_SAVED" or die "Can't dup STDOUT_SAVED: $!"; */
    /* open first closes STDOUT */
    status = Perl_do_open9(aTHX_ handle_orig, ">&", 2, FALSE, O_WRONLY,
                           0, Nullfp, (SV*)handle, 1);
    Perl_do_close(aTHX_ handle, FALSE);
    (void)hv_delete(gv_stashpv("Apache::RequestIO", TRUE), 
		    GvNAME(handle), GvNAMELEN(handle), G_DISCARD);
    if (status == 0) {
        Perl_croak(aTHX_ "Failed to restore STDOUT: %_", get_sv("!", TRUE));
    }

    MP_TRACE_o(MP_FUNC, "end\n");
}
