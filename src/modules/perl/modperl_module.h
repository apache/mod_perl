#ifndef MODPERL_MODULE_H
#define MODPERL_MODULE_H

PTR_TBL_t *modperl_module_config_table_get(pTHX_ int create);

void modperl_module_config_table_set(pTHX_ PTR_TBL_t *table);

const char *modperl_module_add(apr_pool_t *p, server_rec *s,
                               const char *name);

SV *modperl_module_config_get_obj(pTHX_ SV *pmodule, server_rec *s, 
                                  ap_conf_vector_t *v);

#endif /* MODPERL_MODULE_H */
