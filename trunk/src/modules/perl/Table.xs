#include "mod_perl.h"

typedef struct {
    SV *cv;
    table *only;
} TableDo;

#define table_pool(t) ((array_header *)(t))->pool

static int Apache_table_do(TableDo *td, const char *key, const char *val)
{
    int count=0, rv=1;
    dSP;

    if(td->only && !table_get(td->only, key))
       return 1;

    ENTER;SAVETMPS;
    PUSHMARK(sp);
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

static void table_modify(TiedTable *self, const char *key, SV *sv, 
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

static Apache__Table ApacheTable_new(table *table)
{
    Apache__Table RETVAL = (Apache__Table)safemalloc(sizeof(TiedTable));
    RETVAL->table = table;
    RETVAL->ix = 0;
    RETVAL->elts = NULL;
    RETVAL->arr = NULL;
    return RETVAL;
}

MODULE = Apache::Table		PACKAGE = Apache::Table

PROTOTYPES: DISABLE

BOOT:
    items = items; /*avoid warning*/ 

Apache::Table
TIEHASH(class, table)
    SV *class
    Apache::table table

    CODE:
    if(!class) XSRETURN_UNDEF;
    RETVAL = ApacheTable_new(table);

    OUTPUT:
    RETVAL

Apache::Table
new(class, r, nalloc=10)
    SV *class
    Apache r
    int nalloc

    CODE:
    if(!class) XSRETURN_UNDEF;
    RETVAL = ApacheTable_new(make_table(r->pool, nalloc));

    OUTPUT:
    RETVAL

void
DESTROY(self)
    SV *self

    PREINIT:
    Apache__Table tab;

    CODE:
    tab = (Apache__Table)hvrv2table(self);
    if(SvROK(self) && SvTYPE(SvRV(self)) == SVt_PVHV) 
        safefree(tab);

void
FETCH(self, key)
    Apache::Table self
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
    Apache::Table self
    const char *key

    CODE:
    if(!self->table) XSRETURN_UNDEF;
    RETVAL = table_get(self->table, key) ? TRUE : FALSE;

    OUTPUT:
    RETVAL

const char*
DELETE(self, key)
    Apache::Table self
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
    Apache::Table self
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
    Apache::Table self

    ALIAS:
    clear = 1

    CODE:
    ix = ix; /*avoid warning*/
    if(!self->table) XSRETURN_UNDEF;
    clear_table(self->table);

const char *
NEXTKEY(self, lastkey=Nullsv)
    Apache::Table self
    SV *lastkey

    CODE:
    if(self->ix >= self->arr->nelts) XSRETURN_UNDEF;
    RETVAL = self->elts[self->ix++].key;

    OUTPUT:
    RETVAL

const char *
FIRSTKEY(self)
    Apache::Table self

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
    Apache::Table self
    const char *key
    SV *sv;

    CODE:
    table_modify(self, key, sv, table_add);

void
merge(self, key, sv)
    Apache::Table self
    const char *key
    SV *sv

    CODE:
    table_modify(self, key, sv, table_merge);

void
do(self, cv, ...)
    Apache::Table self
    SV *cv

    PREINIT:
    TableDo td;
    td.only = (table *)NULL;

    CODE:
    if(items > 2) {
	int i;
	STRLEN len;
        td.only = make_table(table_pool(self->table), items-2);
	for(i=2; ; i++) {
	    char *key = SvPV(ST(i),len);
	    table_set(td.only, key, "1");
	    if(i == (items - 1)) break; 
	}
    }
    td.cv = cv;

    table_do((int (*) (void *, const char *, const char *)) Apache_table_do,
	    (void *) &td, self->table, NULL);
