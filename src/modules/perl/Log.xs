#ifdef MOD_PERL
#include "mod_perl.h"
#else
#include "modules/perl/mod_perl.h"
#endif

static void ApacheLog(int level, const server_rec *s, SV *msg)
{
    char *file = NULL;
    int line   = 0;
    char *str;
    SV *svstr = Nullsv;
    int lmask = level & APLOG_LEVELMASK;

    if((lmask == APLOG_DEBUG) && (s->loglevel >= APLOG_DEBUG)) {
	SV *caller = perl_eval_pv("[ (caller)[1,2] ]", TRUE);
	file = SvPV(*av_fetch((AV *)SvRV(caller), 0, FALSE),na);
	line = (int)SvIV(*av_fetch((AV *)SvRV(caller), 1, FALSE));
    }

    if((s->loglevel >= lmask) && 
       SvROK(msg) && (SvTYPE(SvRV(msg)) == SVt_PVCV)) {
	dSP;
	ENTER;SAVETMPS;
	PUSHMARK(sp);
	(void)perl_call_sv(msg, G_SCALAR);
	SPAGAIN;
	svstr = POPs;
	++SvREFCNT(svstr);
	PUTBACK;
	FREETMPS;LEAVE;
	str = SvPV(svstr,na);
    }
    else
	str = SvPV(msg,na);

    ap_log_error(file, line, APLOG_NOERRNO|level, s, str);

    SvREFCNT_dec(msg);
    if(svstr) SvREFCNT_dec(svstr);
}

#define join_stack_msg \
SV *msgstr; \
if(items > 2) { \
    msgstr = newSV(0); \
    do_join(msgstr, &sv_no, MARK+1, SP); \
} \
else { \
    msgstr = ST(1); \
    ++SvREFCNT(msgstr); \
} 

#define MP_AP_LOG(l,s) \
{ \
join_stack_msg; \
ApacheLog(l, s, msgstr); \
}

#define Apache_log_emergency(s) \
MP_AP_LOG(APLOG_EMERG, s)

#define Apache_log_alert(s) \
MP_AP_LOG(APLOG_ALERT, s)

#define Apache_log_critical(s) \
MP_AP_LOG(APLOG_CRIT, s)

#define Apache_log_error(s) \
MP_AP_LOG(APLOG_ERR, s)

#define Apache_log_warn(s) \
MP_AP_LOG(APLOG_WARNING, s)

#define Apache_log_notice(s) \
MP_AP_LOG(APLOG_NOTICE, s)

#define Apache_log_info(s) \
MP_AP_LOG(APLOG_INFO, s)

#define Apache_log_debug(s) \
MP_AP_LOG(APLOG_DEBUG, s)

MODULE = Apache::Log		PACKAGE = Apache

PROTOTYPES: DISABLE

BOOT:
    items = items; /*avoid warning*/ 

MODULE = Apache::Log		PACKAGE = Apache::Log PREFIX=Apache_log_

void
Apache_log_emergency(s, ...)
	Apache::Server s

void
Apache_log_alert(s, ...)
	Apache::Server s

void
Apache_log_critical(s, ...)
	Apache::Server s

void
Apache_log_error(s, ...)
	Apache::Server s

void
Apache_log_warn(s, ...)
	Apache::Server s

void
Apache_log_notice(s, ...)
	Apache::Server s

void
Apache_log_info(s, ...)
	Apache::Server s

void
Apache_log_debug(s, ...)
	Apache::Server s






