#define mpxs_APR__Table_FETCH   apr_table_get
#define mpxs_APR__Table_STORE   apr_table_set
#define mpxs_APR__Table_DELETE  apr_table_unset
#define mpxs_APR__Table_CLEAR   apr_table_clear

typedef struct {
    SV *cv;
    apr_hash_t *filter;
    PerlInterpreter *perl;
} mpxs_table_do_cb_data_t;

typedef int (*mpxs_apr_table_do_cb_t)(void *, const char *, const char *);

static int mpxs_apr_table_do_cb(void *data,
                                const char *key, const char *val)
{
    mpxs_table_do_cb_data_t *tdata = (mpxs_table_do_cb_data_t *)data;
    dTHXa(tdata->perl);
    dSP;
    int rv = 0;

    /* Skip completely if something is wrong */
    if (!(tdata && tdata->cv && key && val)) {
        return 0;
    }

    /* Skip entries if not in our filter list */
    if (tdata->filter) {
        if (!apr_hash_get(tdata->filter, key, APR_HASH_KEY_STRING)) {
            return 1;
        }
    }
    
    ENTER;
    SAVETMPS;

    PUSHMARK(sp);
    XPUSHs(sv_2mortal(newSVpv(key,0)));
    XPUSHs(sv_2mortal(newSVpv(val,0)));
    PUTBACK;

    rv = call_sv(tdata->cv, 0);
    SPAGAIN;
    rv = (1 == rv) ? POPi : 1;
    PUTBACK;

    FREETMPS;
    LEAVE;
    
    /* rv of 0 aborts the traversal */
    return rv;
}

static MP_INLINE 
void mpxs_apr_table_do(pTHX_ I32 items, SV **MARK, SV **SP) 
{
    apr_table_t *table;
    SV *sub;
    mpxs_table_do_cb_data_t tdata;
    
    mpxs_usage_va_2(table, sub, "$table->do(sub, [@filter])");
         
    tdata.cv = sub;
    tdata.filter = NULL;
#ifdef USE_ITHREADS
    tdata.perl = aTHX;
#endif

    if (items > 2) {
        char *filter_entry;
        STRLEN len;
        
        tdata.filter = apr_hash_make(table->a.pool);

        while (MARK <= SP) {
            filter_entry = SvPV(*MARK, len);
            apr_hash_set(tdata.filter, filter_entry, len, "1");
            MARK++;
        }
    }
  
    /* XXX: would be nice to be able to call apr_table_vdo directly, 
     * but I don't think it's possible to create/populate something 
     * that smells like a va_list with our list of filters specs
     */
    
    apr_table_do(mpxs_apr_table_do_cb, (void *)&tdata, table, NULL);
    
    /* Free tdata.filter or wait for the pool to go away? */
    
    return; 
}

static MP_INLINE int mpxs_APR__Table_EXISTS(apr_table_t *t, const char *key)
{
    return (NULL == apr_table_get(t, key)) ? 0 : 1;
}

/* Note: SvCUR is used as the iterator state counter, why not ;-? */
#define mpxs_apr_table_iterix(sv) \
SvCUR(SvRV(sv))

#define mpxs_apr_table_nextkey(t, sv) \
   ((apr_table_entry_t *) \
     apr_table_elts(t)->elts)[mpxs_apr_table_iterix(sv)++].key

static MP_INLINE const char *mpxs_APR__Table_NEXTKEY(SV *tsv, SV *key)
{
    dTHX;
    apr_table_t *t = mp_xs_sv2_APR__Table(tsv); 

    if (apr_is_empty_table(t)) {
        return NULL;
    }

    if (mpxs_apr_table_iterix(tsv) < apr_table_elts(t)->nelts) {
        return mpxs_apr_table_nextkey(t, tsv);
    }

    return NULL;
}

static MP_INLINE const char *mpxs_APR__Table_FIRSTKEY(SV *tsv)
{
    mpxs_apr_table_iterix(tsv) = 0; /* reset iterator index */

    return mpxs_APR__Table_NEXTKEY(tsv, Nullsv);
}
