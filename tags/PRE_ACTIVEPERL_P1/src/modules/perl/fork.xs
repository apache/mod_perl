#should no longer need this kludge
# toggle closing of the http socket on fork...
void 
forkoption(i)
    int i;

    CODE: 
    if ((i<0)||(i>3)) { 
	croak("Usage: Apache::forkoption(0|1|2|3)"); 
    }
    else {
	mod_perl_socketexitoption = i;
    } 
    /* probably SHOULD set weareaforkedchild = 0 if socketexitoption
     * is set to something that DOESN'T cause a forked child to
     * actually die on exit, but... 
     */

# We want the http socket closed
int 
fork(...)

    PREINIT:
    listen_rec *l;
    static listen_rec *mhl;
    dSP; dTARGET;
    int childpid;
    GV *tmpgv;

    CODE:
    RETVAL = 0; 
#ifdef HAS_FORK
    items = items; 
    EXTEND(SP,1);
    childpid = fork();

    if((childpid < 0)) {
        RETVAL=-1;
    }
    else {
	if(!childpid) {
 	    if(mod_perl_socketexitoption>1) mod_perl_weareaforkedchild++;
	    if ((mod_perl_socketexitoption==1) ||
                (mod_perl_socketexitoption==3)) {
	        /* So?  I can't get at head_listener...
	         * (It is a ring anyhow...)
                 */
		mhl = listeners;
		l = mhl;

		do {
		    if (l->fd > 0) close(l->fd);
		    l = l->next;
		} while (l != mhl);
	    }
	    if((tmpgv = gv_fetchpv("$", TRUE, SVt_PV)))
	        sv_setiv(GvSV(tmpgv), (IV)getpid());
	    hv_clear(pidstatus);
	}
	PUSHi(childpid);

	RETVAL = childpid;
    }
#else
    croak("Unsupported function fork");
#endif

    OUTPUT:
    RETVAL
