/* ====================================================================
 * The Apache Software License, Version 1.1
 *
 * Copyright (c) 1996-2000 The Apache Software Foundation.  All rights
 * reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in
 *    the documentation and/or other materials provided with the
 *    distribution.
 *
 * 3. The end-user documentation included with the redistribution,
 *    if any, must include the following acknowledgment:
 *       "This product includes software developed by the
 *        Apache Software Foundation (http://www.apache.org/)."
 *    Alternately, this acknowledgment may appear in the software itself,
 *    if and wherever such third-party acknowledgments normally appear.
 *
 * 4. The names "Apache" and "Apache Software Foundation" must
 *    not be used to endorse or promote products derived from this
 *    software without prior written permission. For written
 *    permission, please contact apache@apache.org.
 *
 * 5. Products derived from this software may not be called "Apache",
 *    nor may "Apache" appear in their name, without prior written
 *    permission of the Apache Software Foundation.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESSED OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED.  IN NO EVENT SHALL THE APACHE SOFTWARE FOUNDATION OR
 * ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
 * USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
 * OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 * ====================================================================
 */

#include "mod_perl.h"

#define dHANDLE(name) GV *handle = gv_fetchpv(name, TRUE, SVt_PVIO)

#ifdef PERL_REVISION
#   if ((PERL_REVISION == 5) && (PERL_VERSION >= 7))
#      define TIEHANDLE_SV(handle) (SV*)GvIOp((SV*)handle)
#   endif
#endif

#ifndef TIEHANDLE_SV
#   define TIEHANDLE_SV(handle) (SV*)handle
#endif

#define TIEHANDLE(name,obj) \
{ \
      dHANDLE(name); \
      sv_unmagic(TIEHANDLE_SV(handle), 'q'); \
      sv_magic(TIEHANDLE_SV(handle), obj, 'q', Nullch, 0); \
}

#if 0
#define TIED tied_handle

static int tied_handle(char *name)
{
    dHANDLE(name);

/* XXX so Perl*Handler's can re-tie before PerlHandler is run? 
 * then they'd also be reponsible for re-tie'ing to `Apache'
 * after all PerlHandlers are run, hmm must think.
 */

    MAGIC *mg;
    if (SvMAGICAL(handle) && (mg = mg_find((SV*)handle, 'q'))) {
	char *package = HvNAME(SvSTASH((SV*)SvRV(mg->mg_obj)));
	if(!strEQ(package, "Apache")) {
	    fprintf(stderr, "%s tied to %s\n", GvNAME(handle), package);
	    return TRUE;
	}
    }
    return FALSE;
}
#else
#define TIED(name) 0
#endif

#ifdef USE_SFIO

typedef struct {
    Sfdisc_t     disc;   /* the sfio discipline structure */
    request_rec	*r;
} Apache_t;

static int sfapachewrite(f, buffer, n, disc)
    Sfio_t* f;      /* stream involved */
    char*           buffer;    /* buffer to write from */
    int             n;      /* number of bytes to send */
    Sfdisc_t*       disc;   /* discipline */        
{
    /* feed buffer to Apache->print */
    CV *cv = GvCV(gv_fetchpv("Apache::print", FALSE, SVt_PVCV));
    dSP;
    ENTER;
    SAVETMPS;
    PUSHMARK(sp);
    XPUSHs(perl_bless_request_rec(((Apache_t*)disc)->r));
    XPUSHs(sv_2mortal(newSVpv(buffer,n)));
    PUTBACK;
    (void)(*CvXSUB(cv))(aTHXo_ cv); 
    FREETMPS;
    LEAVE;
    return n;
}

static int sfapacheread(f, buffer, bufsiz, disc)
    Sfio_t* f;      /* stream involved */
    char*           buffer;    /* buffer to read into */
    int             bufsiz;      /* number of bytes to read */
    Sfdisc_t*       disc;   /* discipline */        
{
    dSP;
    int count;
    int nrd;
    SV *sv = sv_newmortal();
    request_rec *r = ((Apache_t*)disc)->r;
    MP_TRACE_g(fprintf(stderr, "sfapacheread: want %d bytes\n", bufsiz)); 
    ENTER;SAVETMPS;
    PUSHMARK(sp);
    XPUSHs(perl_bless_request_rec(r));
    XPUSHs(sv);
    XPUSHs(sv_2mortal(newSViv(bufsiz)));
    PUTBACK;
    count = perl_call_pv("Apache::read", G_SCALAR|G_EVAL);
    SPAGAIN;
    if (SvTRUE(ERRSV)) {
	fprintf (stderr, "Apache::read died %s\n", SvPV(ERRSV, na));
	nrd = -1;
	POPs;
    }
    else {
        char *tmpbuf = SvPV(sv, nrd);
        if(count == 1) {
	    nrd = POPi;
	}
	MP_TRACE_g(fprintf(stderr, "sfapacheread: got %d \"%.*s\"\n",
			   nrd, nrd > 40 ? 40 : nrd, tmpbuf));
        if (nrd > bufsiz) {
	    abort();
	}
	memcpy(buffer, tmpbuf, nrd);
    }
    PUTBACK;
    FREETMPS;LEAVE;
    return nrd;
}

Sfdisc_t * sfdcnewapache(request_rec *r)
{
    Apache_t*   disc;
    
    if(!(disc = (Apache_t*)malloc(sizeof(Apache_t))) )
	return (Sfdisc_t *)disc;
    MP_TRACE_g(fprintf(stderr, "sfdcnewapache(r)\n"));
    disc->disc.readf   = (Sfread_f)sfapacheread; 
    disc->disc.writef  = (Sfwrite_f)sfapachewrite;
    disc->disc.seekf   = (Sfseek_f)NULL;
    disc->disc.exceptf = (Sfexcept_f)NULL;
    disc->r = r;
    return (Sfdisc_t *)disc;
}
#endif

void perl_soak_script_output(request_rec *r)
{
    SV *sv = sv_newmortal();
    sv_setref_pv(sv, "Apache::FakeRequest", (void*)r);

    if(!perl_get_cv("Apache::FakeRequest::PRINT", FALSE)) 
	(void)perl_eval_pv("package Apache::FakeRequest; sub PRINT {}; sub PRINTF {}", TRUE);

#ifdef USE_SFIO
    sfdisc(PerlIO_stdout(), SF_POPDISC);
#endif

    TIEHANDLE("STDOUT", sv);

    /* we're most likely in the middle of send_cgi_header(), 
       * flick this switch so send_http_header() isn't called
       */
    mod_perl_sent_header(r, TRUE);
}

void perl_stdout2client(request_rec *r)
{
    dTHR;
#ifdef USE_SFIO
    sfdisc(PerlIO_stdout(), SF_POPDISC);
    sfdisc(PerlIO_stdout(), sfdcnewapache(r));
    IoFLAGS(GvIOp(defoutgv)) |= IOf_FLUSH; /* $|=1 */
#else
    IoFLAGS(GvIOp(defoutgv)) &= ~IOf_FLUSH; /* $|=0 */

    if(TIED("STDOUT")) return; 
    MP_TRACE_g(fprintf(stderr, "tie *STDOUT => Apache\n"));
    TIEHANDLE("STDOUT", perl_bless_request_rec(r));
#endif
}

void perl_stdin2client(request_rec *r)
{
#ifdef USE_SFIO
    sfdisc(PerlIO_stdin(), SF_POPDISC);
    sfdisc(PerlIO_stdin(), sfdcnewapache(r));
    sfsetbuf(PerlIO_stdin(), NULL, 0);
#else
    if(TIED("STDIN")) return; 
    MP_TRACE_g(fprintf(stderr, "tie *STDIN => Apache\n"));
    TIEHANDLE("STDIN", perl_bless_request_rec(r));
#endif
}
