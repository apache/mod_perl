#ifdef MOD_PERL
#include "mod_perl.h"
#else
#include "modules/perl/mod_perl.h"
#endif  

typedef struct {
    uri_components uri;
    pool *pool;
    request_rec *r;
    char *path_info;
} XS_Apache__URI;

typedef XS_Apache__URI * Apache__URI;

MODULE = Apache::URI		PACKAGE = Apache

PROTOTYPES: DISABLE

BOOT:
    items = items; /*avoid warning*/ 

Apache::URI
parsed_uri(r)
    Apache r

    CODE:
    RETVAL = (Apache__URI)safemalloc(sizeof(XS_Apache__URI));
    RETVAL->uri = r->parsed_uri;
    RETVAL->pool = r->pool; 
    RETVAL->r = r;
    RETVAL->path_info = r->path_info;

    OUTPUT:
    RETVAL

MODULE = Apache::URI		PACKAGE = Apache::URI		

void
DESTROY(uri)
    Apache::URI uri

    CODE:
    safefree(uri);

Apache::URI
parse(self, r, uri)
    SV *self
    Apache r
    const char *uri

    CODE:
    self = self; /* -Wall */ 
    RETVAL = (Apache__URI)safemalloc(sizeof(XS_Apache__URI));
    
    (void)ap_parse_uri_components(r->pool, uri, &RETVAL->uri);
    RETVAL->pool = r->pool;
    RETVAL->r = r;
    RETVAL->path_info = NULL;

    OUTPUT:
    RETVAL

char *
unparse(uri, flags=UNP_OMITPASSWORD)
    Apache::URI uri
    unsigned flags

    CODE:
    RETVAL = ap_unparse_uri_components(uri->pool, &uri->uri, flags);

    OUTPUT:
    RETVAL

SV *
rpath(uri)
    Apache::URI uri

    CODE:

    if(uri->path_info) {
	int uri_len = strlen(uri->uri.path);
        int n = strlen(uri->path_info);
	int set = uri_len - n;
	if(set > 0)
	    RETVAL = newSVpv(uri->uri.path, set);
    } 
    else
        RETVAL = newSVpv(uri->uri.path, 0);

    OUTPUT:
    RETVAL 

char *
scheme(uri, set=Nullsv)
    Apache::URI uri
    SV *set

    CODE:
    RETVAL = uri->uri.scheme;

    if(set) 
        uri->uri.scheme = SvPV(set,na);

    OUTPUT:
    RETVAL 

char *
hostinfo(uri, set=Nullsv)
    Apache::URI uri
    SV *set

    CODE:
    RETVAL = uri->uri.hostinfo;

    if(set) 
        uri->uri.hostinfo = SvPV(set,na);

    OUTPUT:
    RETVAL 

char *
user(uri, set=Nullsv)
    Apache::URI uri
    SV *set

    CODE:
    RETVAL = uri->uri.user;

    if(set) 
        uri->uri.user = SvPV(set,na);

    OUTPUT:
    RETVAL 

char *
password(uri, set=Nullsv)
    Apache::URI uri
    SV *set

    CODE:
    RETVAL = uri->uri.password;

    if(set) 
        uri->uri.password = SvPV(set,na);

    OUTPUT:
    RETVAL 

char *
hostname(uri, set=Nullsv)
    Apache::URI uri
    SV *set

    CODE:
    RETVAL = uri->uri.hostname;

    if(set) 
        uri->uri.hostname = SvPV(set,na);

    OUTPUT:
    RETVAL 

char *
path(uri, set=Nullsv)
    Apache::URI uri
    SV *set

    CODE:
    RETVAL = uri->uri.path;

    if(set) 
        uri->uri.path = SvPV(set,na);

    OUTPUT:
    RETVAL 

char *
query(uri, set=Nullsv)
    Apache::URI uri
    SV *set

    CODE:
    RETVAL = uri->uri.query;

    if(set) 
        uri->uri.query = SvPV(set,na);

    OUTPUT:
    RETVAL 

char *
fragment(uri, set=Nullsv)
    Apache::URI uri
    SV *set

    CODE:
    RETVAL = uri->uri.fragment;

    if(set) 
        uri->uri.fragment = SvPV(set,na);

    OUTPUT:
    RETVAL 

char *
port(uri, set=Nullsv)
    Apache::URI uri
    SV *set

    CODE:
    RETVAL = uri->uri.port_str;

    if(set) 
        uri->uri.port_str = SvPV(set,na);

    OUTPUT:
    RETVAL 

char *
path_info(uri, set=Nullsv)
    Apache::URI uri
    SV *set

    CODE:
    RETVAL = uri->path_info;

    if(set) 
        uri->path_info = SvPV(set,na);

    OUTPUT:
    RETVAL 

            
