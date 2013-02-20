/* Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "mod_perl.h"

#define TIEHANDLE(handle,r) \
modperl_io_handle_tie(aTHX_ handle, "Apache2::RequestRec", (void *)r)

#define TIED(handle) \
modperl_io_handle_tied(aTHX_ handle, "Apache2::RequestRec")

MP_INLINE void modperl_io_handle_tie(pTHX_ GV *handle,
                                     char *classname, void *ptr)
{
    SV *obj = modperl_ptr2obj(aTHX_ classname, ptr);

    modperl_io_handle_untie(aTHX_ handle);

    sv_magic(TIEHANDLE_SV(handle), obj, PERL_MAGIC_tiedscalar, (char *)NULL, 0);

    SvREFCNT_dec(obj); /* since sv_magic did SvREFCNT_inc */

    MP_TRACE_r(MP_FUNC, "tie *%s(0x%lx) => %s, REFCNT=%d",
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

    if (SvMAGICAL(sv) && (mg = mg_find(sv, PERL_MAGIC_tiedscalar))) {
        char *package = HvNAME(SvSTASH((SV*)SvRV(mg->mg_obj)));

        if (!strEQ(package, classname)) {
            MP_TRACE_r(MP_FUNC, "%s tied to %s", GvNAME(handle), package);
            return TRUE;
        }
    }

    return FALSE;
}

MP_INLINE void modperl_io_handle_untie(pTHX_ GV *handle)
{
#ifdef MP_TRACE
    if (mg_find(TIEHANDLE_SV(handle), PERL_MAGIC_tiedscalar)) {
        MP_TRACE_r(MP_FUNC, "untie *%s(0x%lx), REFCNT=%d",
                   GvNAME(handle), (unsigned long)handle,
                   SvREFCNT(TIEHANDLE_SV(handle)));
    }
#endif

    sv_unmagic(TIEHANDLE_SV(handle), PERL_MAGIC_tiedscalar);
}

MP_INLINE static void
modperl_io_perlio_override_stdhandle(pTHX_ request_rec *r, int mode)
{
    dHANDLE(mode == O_RDONLY ? "STDIN" : "STDOUT");
    int status;
    SV *sv = sv_newmortal();

    MP_TRACE_o(MP_FUNC, "start STD%s", mode == O_RDONLY ? "IN" : "OUT");

    save_gp(handle, 1);

    sv_setref_pv(sv, "Apache2::RequestRec", (void*)r);
    status = do_open9(handle, mode == O_RDONLY ? "<:Apache2" : ">:Apache2",
                      9, FALSE, mode, 0, (PerlIO *)NULL, sv, 1);
    if (status == 0) {
        Perl_croak(aTHX_ "Failed to open STD%s: %" SVf,
                   mode == O_RDONLY ? "IN" : "OUT", get_sv("!", TRUE));
    }

    MP_TRACE_o(MP_FUNC, "end STD%s", mode==O_RDONLY ? "IN" : "OUT");
}

MP_INLINE static void
modperl_io_perlio_restore_stdhandle(pTHX_ int mode)
{
    GV *handle_orig = gv_fetchpv(mode == O_RDONLY ? "STDIN" : "STDOUT",
                                 FALSE, SVt_PVIO);

    MP_TRACE_o(MP_FUNC, "start STD%s", mode == O_RDONLY ? "IN" : "OUT");

    /* since closing unflushed STDOUT may trigger a subrequest
     * (e.g. via mod_include), resulting in potential another response
     * handler call, which may try to close STDOUT too. We will
     * segfault, if that subrequest doesn't return before the the top
     * level STDOUT is attempted to be closed. To prevent this
     * situation always explicitly flush STDOUT, before reopening it.
     */
    if (mode != O_RDONLY &&
        GvIOn(handle_orig) && IoOFP(GvIOn(handle_orig)) &&
        (PerlIO_flush(IoOFP(GvIOn(handle_orig))) == -1)) {
        Perl_croak(aTHX_ "Failed to flush STDOUT: %" SVf, get_sv("!", TRUE));
    }

    /* close the overriding filehandle */
    do_close(handle_orig, FALSE);

    MP_TRACE_o(MP_FUNC, "end STD%s", mode == O_RDONLY ? "IN" : "OUT");
}

MP_INLINE GV *modperl_io_perlio_override_stdin(pTHX_ request_rec *r)
{
    modperl_io_perlio_override_stdhandle(aTHX_ r, O_RDONLY);
    return NULL;
}

MP_INLINE GV *modperl_io_perlio_override_stdout(pTHX_ request_rec *r)
{
    modperl_io_perlio_override_stdhandle(aTHX_ r, O_WRONLY);
    return NULL;
}

MP_INLINE void modperl_io_perlio_restore_stdin(pTHX_ GV *handle)
{
    modperl_io_perlio_restore_stdhandle(aTHX_ O_RDONLY);
}

MP_INLINE void modperl_io_perlio_restore_stdout(pTHX_ GV *handle)
{
    modperl_io_perlio_restore_stdhandle(aTHX_ O_WRONLY);
}

