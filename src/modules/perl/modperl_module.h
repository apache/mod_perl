#ifndef MODPERL_MODULE_H
#define MODPERL_MODULE_H

PTR_TBL_t *modperl_module_config_table_get(pTHX_ int create);

void modperl_module_config_table_set(pTHX_ PTR_TBL_t *table);

const char *modperl_module_add(apr_pool_t *p, server_rec *s,
                               const char *name);

#endif /* MODPERL_MODULE_H */
