static void mpxs_Apache__Log_BOOT(pTHXo)
{
    av_push(get_av("Apache::Log::Request::ISA",TRUE), 
            newSVpv("Apache::Log",11));
    av_push(get_av("Apache::Log::Server::ISA",TRUE), 
            newSVpv("Apache::Log",11));
}

#define croak_inval_obj() \
Perl_croak(aTHX_ "Argument is not an Apache::RequestRec " \
                 "or Apache::Server object")

static void mpxs_ap_log_error(pTHX_ int level, SV *sv, SV *msg)
{
    char *file = NULL;
    int line = 0;
    char *str;
    SV *svstr = Nullsv;
    STRLEN n_a;
    int lmask = level & APLOG_LEVELMASK;
    server_rec *s;
    request_rec *r = NULL;

    if (SvROK(sv) && sv_isa(sv, "Apache::Log::Request")) {
        r = (request_rec *)SvObjIV(sv);
        s = r->server;
    }
    else if (SvROK(sv) && sv_isa(sv, "Apache::Log::Server")) {
        s = (server_rec *)SvObjIV(sv);
    }
    else {
        s = modperl_global_get_server_rec();
    }

    if ((lmask == APLOG_DEBUG) && (s->loglevel >= APLOG_DEBUG)) {
        COP *cop = PL_curcop;
        file = CopFILE(cop); /* (caller)[1] */
        line = CopLINE(cop); /* (caller)[2] */
    }

    if ((s->loglevel >= lmask) && 
        SvROK(msg) && (SvTYPE(SvRV(msg)) == SVt_PVCV))
    {
        dSP;
        ENTER;SAVETMPS;
        PUSHMARK(sp);
        (void)call_sv(msg, G_SCALAR);
        SPAGAIN;
        svstr = POPs;
        (void)SvREFCNT_inc(svstr);
        PUTBACK;
        FREETMPS;LEAVE;
        str = SvPV(svstr,n_a);
    }
    else {
        str = SvPV(msg,n_a);
    }

    if (r) {
        ap_log_rerror(file, line, APLOG_NOERRNO|level, 0, r, "%s", str);
    }
    else {
        ap_log_error(file, line, APLOG_NOERRNO|level, 0, s, "%s", str);
    }

    if (svstr) {
        SvREFCNT_dec(svstr);
    }
}

#define MP_LOG_REQUEST 1
#define MP_LOG_SERVER  2

static SV *mpxs_Apache__Log_log(pTHX_ SV *sv, int logtype)
{
    SV *svretval;
    void *retval;
    char *pclass;

    switch (logtype) {
      case MP_LOG_REQUEST:
        pclass = "Apache::Log::Request";
        retval = (void *)modperl_sv2request_rec(aTHX_ sv);
        break;
      case MP_LOG_SERVER:
        pclass = "Apache::Log::Server";
        retval = (void *)modperl_sv2server_rec(aTHX_ sv);
        break;
      default:
        croak_inval_obj();
    };

    svretval = newSV(0);
    sv_setref_pv(svretval, pclass, (void*)retval);

    return svretval;
}

#define mpxs_Apache__RequestRec_log(sv) \
mpxs_Apache__Log_log(aTHX_ sv, MP_LOG_REQUEST)

#define mpxs_Apache__Server_log(sv) \
mpxs_Apache__Log_log(aTHX_ sv, MP_LOG_SERVER)

static MP_INLINE SV *modperl_perl_do_join(pTHX_ SV **mark, SV **sp)
{
    SV *sv = newSV(0);
    SV *delim;
#ifdef WIN32
    /* XXX: using PL_sv_no crashes on win32 with 5.6.1 */
    delim = newSVpv("", 0);
#else
    delim = SvREFCNT_inc(&PL_sv_no);
#endif

    do_join(sv, delim, mark, sp);

    SvREFCNT_dec(delim);

    return sv;
}

#define my_do_join(m, s) \
   modperl_perl_do_join(aTHX_ (m), (s))

static XS(MPXS_Apache__Log_dispatch)
{
    dXSARGS;
    SV *msgsv;
    int level;
    char *name = GvNAME(CvGV(cv));

    if (items < 2) {
        Perl_croak(aTHX_ "usage: %s::%s(obj, ...)",
                   mpxs_cv_name());
    }

    if (items > 2) {
        msgsv = my_do_join(MARK+1, SP);
    }
    else {
        msgsv = ST(1);
        (void)SvREFCNT_inc(msgsv);
    }

    switch (*name) {
      case 'e':
        if (*(name + 1) == 'r') {
            level = APLOG_ERR;
            break;
        }
        level = APLOG_EMERG;
        break;
      case 'w':
        level = APLOG_WARNING;
        break;
      case 'n':
        level = APLOG_NOTICE;
        break;
      case 'i':
        level = APLOG_INFO;
        break;
      case 'd':
        level = APLOG_DEBUG;
        break;
      case 'a':
        level = APLOG_ALERT;
        break;
      case 'c':
        level = APLOG_CRIT;
        break;
      default:
        level = APLOG_ERR; /* should never get here */
        break;
    };

    mpxs_ap_log_error(aTHX_ level, ST(0), msgsv);

    SvREFCNT_dec(msgsv);

    XSRETURN_EMPTY;
}

static XS(MPXS_Apache_LOG_MARK)
{
    dXSARGS;
    ax = ax; /* -Wall */;

    mpxs_PPCODE({
        COP *cop = PL_curcop;

        if (items) {
            Perl_croak(aTHX_ "usage %s::%s()", mpxs_cv_name());
        }

        EXTEND(SP, 2);
        PUSHs_mortal_pv(CopFILE(cop));
        PUSHs_mortal_iv(CopLINE(cop));
    });
}

static XS(MPXS_Apache__Log_log_xerror)
{
    dXSARGS;
    SV *msgsv = Nullsv;
    STRLEN n_a;
    request_rec *r = NULL;
    server_rec *s = NULL;
    char *msgstr;
    const char *file;
    int line, level;
    apr_status_t status;

    if (items < 6) {
        Perl_croak(aTHX_ "usage %s::%s(file, line, level, status, ...)",
                   mpxs_cv_name());
    }

    switch (*(GvNAME(CvGV(cv)) + 4)) { /* 4 == log_ */
      case 'r':
        r = modperl_xs_sv2request_rec(aTHX_ ST(0), NULL, cv);
        break;
      case 's':
        s = modperl_sv2server_rec(aTHX_ ST(0));
        break;
      default:
        croak_inval_obj();
    };

    file   = (const char *)SvPV(ST(1), n_a);
    line   = (int)SvIV(ST(2));
    level  = (int)SvIV(ST(3));
    status = (apr_status_t)SvIV(ST(4));

    if (items > 6) {
        msgsv = my_do_join(MARK+5, SP);
    }
    else {
        msgsv = ST(5);
        (void)SvREFCNT_inc(msgsv);
    }

    msgstr = SvPV(msgsv, n_a);

    if (r) {
        ap_log_rerror(file, line, level, status, r, "%s", msgstr);
    }
    else {
        ap_log_error(file, line, level, status, s, "%s", msgstr);
    }

    SvREFCNT_dec(msgsv);

    XSRETURN_EMPTY;
}

static XS(MPXS_Apache__Log_log_error)
{
    dXSARGS;
    request_rec *r = NULL;
    server_rec *s = NULL;
    int i=0;
    char *errstr = NULL;
    SV *sv = Nullsv;
    STRLEN n_a;

    /*
     * we support the following:
     * Apache::warn
     * Apache->warn
     * $r->warn
     * $r->log_error
     * Apache::Server->log_error
     * $s->log_error
     * Apache::Server->warn
     * $s->warn
     */

    if (items > 1) {
        if ((r = modperl_xs_sv2request_rec(aTHX_ ST(0),
                                           "Apache::RequestRec", cv)))
        {
            s = r->server;
        }
        else if (sv_isa(ST(0), "Apache::Server")) {
            s = (server_rec *)SvObjIV(ST(0));
        }
        else if (SvPOK(ST(0)) && strEQ(SvPVX(ST(0)), "Apache::Server")) {
            s = modperl_global_get_server_rec();
        }
    }
              
    if (s) {
        i=1;
    }
    else {
        s = modperl_global_get_server_rec();
    }

    if (items > 1+i) {
        sv = my_do_join(MARK+i, SP); /* $sv = join '', @_[1..$#_] */
        errstr = SvPV(sv,n_a);
    }
    else {
        errstr = SvPV(ST(i),n_a);
    }

    switch (*GvNAME(CvGV(cv))) {
      case 'w':
        modperl_log_warn(s, errstr);
        break;
      default:
        modperl_log_error(s, errstr);
        break;
    }

    if (sv) {
        SvREFCNT_dec(sv);
    }

    XSRETURN_EMPTY;
}
