#include "mod_perl.h"

typedef struct {
    table *table;
    array_header *arr;
    table_entry *elts;
    int ix;
} apache_tiehash_table;

typedef apache_tiehash_table * Apache__TieHashTable;

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
add(self, key, val)
    Apache::TieHashTable self
    const char *key
    const char *val

    CODE:
    if(!self->table) XSRETURN_UNDEF;
    table_add(self->table, key, val);

void
merge(self, key, val)
    Apache::TieHashTable self
    const char *key
    const char *val

    CODE:
    if(!self->table) XSRETURN_UNDEF;
    table_merge(self->table, key, val);







