#ifndef MODPERL_OPTIONS_H
#define MODPERL_OPTIONS_H

modperl_options_t *modperl_options_new(apr_pool_t *p, int type);

const char *modperl_options_set(apr_pool_t *p, modperl_options_t *o,
                                const char *s);

modperl_options_t *modperl_options_merge(apr_pool_t *p,
                                         modperl_options_t *base,
                                         modperl_options_t *new);

#endif /* MODPERL_OPTIONS_H */
