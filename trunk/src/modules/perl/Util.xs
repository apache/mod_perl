#ifdef MOD_PERL
#include "mod_perl.h"
#else
#include "modules/perl/mod_perl.h"
#endif 

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

MODULE = Apache::Util		PACKAGE = Apache::Util		

PROTOTYPES: DISABLE

BOOT:
    items = items; /*avoid warning*/
                                         
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

    
