#include "mod_perl.h"

typedef struct {
    table *table;
    array_header *arr;
    table_entry *elts;
    int ix;
} apache_tiehash_table;

typedef apache_tiehash_table * Apache__TieHashTable;

typedef struct {
    SV *sv;
    SV *cv;
    HV *hv;
} TableDo;

static int Apache_table_do(TableDo *td, const char *key, const char *val)
{
    int count=0, rv=1;
    dSP;

    if(td->hv && !hv_exists(td->hv, (char*)key, strlen(key))) 
       return 1;

    ENTER;SAVETMPS;
    PUSHMARK(sp);
    if(td->sv && (td->sv != &sv_undef))
	XPUSHs(td->sv);
    XPUSHs(sv_2mortal(newSVpv((char *)key,0)));
    XPUSHs(sv_2mortal(newSVpv((char *)val,0)));
    PUTBACK;
    count = perl_call_sv(td->cv, G_SCALAR);
    SPAGAIN;
    if(count == 1)
	rv = POPi;
    PUTBACK;
    FREETMPS;LEAVE;
    return rv;
}

static void table_modify(apache_tiehash_table *self, const char *key, SV *sv, 
			 void (*tabfunc) (table *, const char *, const char *))
{
    const char *val;

    if(!self->table) return;

    if(SvROK(sv) && (SvTYPE(SvRV(sv)) == SVt_PVAV)) {
	I32 i;
	AV *av = (AV*)SvRV(sv);
	for(i=0; i<=AvFILL(av); i++) {
	    val = (const char *)SvPV(*av_fetch(av, i, FALSE),na);
            (*tabfunc)(self->table, key, val);
	}
    }
    else {
        val = (const char *)SvPV(sv,na);
	(*tabfunc)(self->table, key, val);
    }

}

MODULE = Apache::Tie		PACKAGE = Apache::TieHashTable

PROTOTYPES: DISABLE

BOOT:
    items = items; /*avoid warning*/ 

Apache::TieHashTable
TIEHASH(class, table)
    SV *class
    Apache::Table table

    CODE:
    if(!class) XSRETURN_UNDEF;
    RETVAL = (Apache__TieHashTable)safemalloc(sizeof(apache_tiehash_table));
    RETVAL->table = table;
    RETVAL->ix = 0;
    RETVAL->elts = NULL;
    RETVAL->arr = NULL;

    OUTPUT:
    RETVAL

void
destroy(self)
    Apache::TieHashTable self

    CODE:
    safefree(self);

void
FETCH(self, key)
    Apache::TieHashTable self
    const char *key

    ALIAS:
    get = 1

    PPCODE:
    ix = ix; /*avoid warning*/
    if(!self->table) XSRETURN_UNDEF;
    if(GIMME == G_SCALAR) {
	const char *val = table_get(self->table, key);
	if (val) XPUSHs(sv_2mortal(newSVpv((char*)val,0)));
	else XSRETURN_UNDEF;
    }
    else {
	int i;
	array_header *arr  = table_elts(self->table);
	table_entry *elts = (table_entry *)arr->elts;
	for (i = 0; i < arr->nelts; ++i) {
	    if (!elts[i].key || strcasecmp(elts[i].key, key)) continue;
	    XPUSHs(sv_2mortal(newSVpv(elts[i].val,0)));
	}
    }

bool
EXISTS(self, key)
    Apache::TieHashTable self
    const char *key

    CODE:
    if(!self->table) XSRETURN_UNDEF;
    RETVAL = table_get(self->table, key) ? TRUE : FALSE;

    OUTPUT:
    RETVAL

const char*
DELETE(self, key)
    Apache::TieHashTable self
    const char *key

    ALIAS:
    unset = 1

    PREINIT:
    I32 gimme = GIMME_V;

    CODE:
    ix = ix;
    if(!self->table) XSRETURN_UNDEF;
    RETVAL = NULL;
    if(gimme != G_VOID)
        RETVAL = table_get(self->table, key);
    table_unset(self->table, key);
    if(!RETVAL) XSRETURN_UNDEF;

    OUTPUT:
    RETVAL

void
STORE(self, key, val)
    Apache::TieHashTable self
    const char *key
    const char *val

    ALIAS:
    set = 1

    CODE:
    ix = ix; /*avoid warning*/
    if(!self->table) XSRETURN_UNDEF;
    table_set(self->table, key, val);

void
CLEAR(self)
    Apache::TieHashTable self

    ALIAS:
    clear = 1

    CODE:
    ix = ix; /*avoid warning*/
    if(!self->table) XSRETURN_UNDEF;
    clear_table(self->table);

const char *
NEXTKEY(self, lastkey=Nullsv)
    Apache::TieHashTable self
    SV *lastkey

    CODE:
    if(self->ix >= self->arr->nelts) XSRETURN_UNDEF;
    RETVAL = self->elts[self->ix++].key;

    OUTPUT:
    RETVAL

const char *
FIRSTKEY(self)
    Apache::TieHashTable self

    CODE:
    if(!self->table) XSRETURN_UNDEF;
    self->arr = table_elts(self->table);
    if(!self->arr->nelts) XSRETURN_UNDEF;
    self->elts = (table_entry *)self->arr->elts;
    self->ix = 0;
    RETVAL = self->elts[self->ix++].key;

    OUTPUT:
    RETVAL

void
add(self, key, sv)
    Apache::TieHashTable self
    const char *key
    SV *sv;

    CODE:
    table_modify(self, key, sv, table_add);

void
merge(self, key, sv)
    Apache::TieHashTable self
    const char *key
    SV *sv

    CODE:
    table_modify(self, key, sv, table_merge);

void
do(self, cv, sv=Nullsv, ...)
    Apache::TieHashTable self
    SV *cv
    SV *sv

    PREINIT:
    TableDo td;
    HV *hv = Nullhv;

    CODE:
    if(items > 3) {
	int i;
	STRLEN len;
	hv = newHV();
	for(i=3; ; i++) {
	    char *key = SvPV(ST(i),len);
	    hv_store(hv, key, len, newSViv(1), FALSE);
	    if(i == (items - 1)) break; 
	}
    }
    td.sv = sv;
    td.cv = cv;
    td.hv = hv;

    table_do((int (*) (void *, const char *, const char *)) Apache_table_do,
	    (void *) &td, self->table, NULL);

    if(hv) SvREFCNT_dec(hv);
