#ifndef MODPERL_SVPTR_TABLE_H
#define MODPERL_SVPTR_TABLE_H

#ifdef USE_ITHREADS

PTR_TBL_t *modperl_svptr_table_clone(pTHX_ PerlInterpreter *proto_perl,
                                     PTR_TBL_t *source);

#endif

void modperl_svptr_table_destroy(pTHX_ PTR_TBL_t *tbl);

void modperl_svptr_table_delete(pTHX_ PTR_TBL_t *tbl, void *key);

/*
 * XXX: the following are a copy of the Perl 5.8.0 Perl_ptr_table api
 * renamed s/Perl_ptr/modperl_svptr/g;
 * two reasons:
 *   these functions do not exist without -DUSE_ITHREADS
 *   the clear/free functions do not exist in 5.6.x
 */

PTR_TBL_t *
modperl_svptr_table_new(pTHX);

void *
modperl_svptr_table_fetch(pTHX_ PTR_TBL_t *tbl, void *sv);

void
modperl_svptr_table_store(pTHX_ PTR_TBL_t *tbl, void *oldv, void *newv);

void
modperl_svptr_table_split(pTHX_ PTR_TBL_t *tbl);

void
modperl_svptr_table_clear(pTHX_ PTR_TBL_t *tbl);

void
modperl_svptr_table_free(pTHX_ PTR_TBL_t *tbl);

#endif /* MODPERL_SVPTR_TABLE_H */
