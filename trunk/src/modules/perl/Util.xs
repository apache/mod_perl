#ifdef MOD_PERL
#include "mod_perl.h"
#else
#include "modules/perl/mod_perl.h"
#endif 

#include "util_date.h"

#define TIME_NOW time(NULL)
#define DEFAULT_TIME_FORMAT "%a, %d %b %Y %H:%M:%S %Z"

#define parsedate ap_parseHTTPdate
 
static pool *util_pool(void)
{
    request_rec *r = NULL;

    if((r = perl_request_rec(NULL)))
        return r->pool;
    else
        return perl_get_startup_pool();
    return NULL;
}

static SV *size_string(size_t size)
{
    SV *sv = newSVpv("    -", 5);
    if (size == (size_t)-1) {
	/**/
    }
    else if (!size) {
	sv_setpv(sv, "   0k");
    }
    else if (size < 1024) {
	sv_setpv(sv, "   1k");
    }
    else if (size < 1048576) {
	sv_setpvf(sv, "%4dk", (size + 512) / 1024);
    }
    else if (size < 103809024) {
	sv_setpvf(sv, "%4.1fM", size / 1048576.0);
    }
    else {
	sv_setpvf(sv, "%4dM", (size + 524288) / 1048576);
    }

    return sv;
}

MODULE = Apache::Util		PACKAGE = Apache::Util		

PROTOTYPES: DISABLE

BOOT:
    items = items; /*avoid warning*/

SV *
size_string(size)
    size_t size

char *
escape_uri(segment)
    const char *segment

    CODE:
    RETVAL = ap_os_escape_path(util_pool(), segment, TRUE);

    OUTPUT:
    RETVAL

char *
escape_html(s)
    const char *s

    CODE:
    RETVAL = escape_html(util_pool(),s);

    OUTPUT:
    RETVAL

char *
ht_time(t=TIME_NOW, fmt=DEFAULT_TIME_FORMAT, gmt=TRUE)
    time_t t
    const char *fmt
    int gmt

    CODE:
    RETVAL = ap_ht_time(util_pool(), t, fmt, gmt);

    OUTPUT:
    RETVAL

time_t
parsedate(date)
    const char *date

    
