/* handy macros for RETVAL */

#define get_set_PV(thing) \
    RETVAL = (char*)thing; \
    if(items > 1) \
        (char*)thing = (ST(1) == &sv_undef) ? NULL : pstrdup(r->pool, SvPV(ST(1),na))

#define get_set_IV(thing) \
    RETVAL = thing; \
    if(items > 1) \
        thing = (int)SvIV(ST(1))

#define TABLE_GET_SET(table, do_taint) \
if(key == NULL) { \
    ST(0) = mod_perl_tie_table(table); \
    XSRETURN(1); \
} \
else { \
    char *val; \
    if(table && (val = (char *)table_get(table, key))) \
	RETVAL = newSVpv(val, 0); \
    else \
        RETVAL = newSV(0); \
    if(do_taint) SvTAINTED_on(RETVAL); \
    if(table && (items > 2)) { \
	if(ST(2) == &sv_undef) \
	    table_unset(table, key); \
	else \
	    table_set(table, key, SvPV(ST(2),na)); \
    } \
}

#define MP_CHECK_REQ(r,f) \
    if(!r) croak("`%s' called without setting Apache->request!", f)

/* request_rec */
#define mod_perl_finfo(r) \
statcache = r->finfo

/* for Apache::fork, should no longer need */
#ifdef Apache__fork
extern listen_rec *listeners;
extern int mod_perl_socketexitoption;
extern int mod_perl_weareaforkedchild;   
#define Apache_exit_is_done(sts) \
 ((sts == DONE) || (mod_perl_weareaforkedchild && (mod_perl_socketexitoption > 1)))  
#else 
#define Apache_exit_is_done(sts) (sts == DONE)
#endif

