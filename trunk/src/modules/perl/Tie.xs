#include "modules/perl/mod_perl.h"

typedef struct {
    table *table;
    array_header *arr;
    table_entry *elts;
    int ix;
} apache_tiehash_table;

typedef apache_tiehash_table * Apache__TieHashTable;

MODULE = Apache::Tie		PACKAGE = Apache::TieHashTable

Apache::TieHashTable
TIEHASH(class, table)
    SV *class
    Apache::Table table

    CODE:
    RETVAL = (Apache__TieHashTable)safemalloc(sizeof(apache_tiehash_table));
    RETVAL->table = table;
    RETVAL->ix = 0;
    RETVAL->elts = NULL;
    RETVAL->arr = NULL;

    OUTPUT:
    RETVAL

void
DESTROY(self)
    Apache::TieHashTable self

    CODE:
    safefree(self);

const char*
FETCH(self, key)
    Apache::TieHashTable self
    const char *key

    ALIAS:
    get = 1

    CODE:
    if(!self->table) XSRETURN_UNDEF;
    RETVAL = table_get(self->table, key);

    OUTPUT:
    RETVAL

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
    if(!self->table) XSRETURN_UNDEF;
    if(gimme != G_VOID)
        RETVAL = table_get(self->table, key);
    table_unset(self->table, key);

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
    if(!self->table) XSRETURN_UNDEF;
    table_set(self->table, key, val);

void
CLEAR(self)
    Apache::TieHashTable self

    ALIAS:
    clear = 1

    CODE:
    if(!self->table) XSRETURN_UNDEF;
    clear_table(self->table);

const char *
NEXTKEY(self, lastkey)
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







