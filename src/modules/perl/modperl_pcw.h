#ifndef MODPERL_PCW_H
#define MODPERL_PCW_H

typedef int (*ap_pcw_dir_walker) (apr_pool_t *, server_rec *,
                                  void *, char *, void *);

typedef int (*ap_pcw_srv_walker) (apr_pool_t *, server_rec *,
                                  void *, void *);

void ap_pcw_walk_location_config(apr_pool_t *pconf, server_rec *s,
                                 core_server_config *sconf,
                                 module *modp,
                                 ap_pcw_dir_walker dw, void *data);

void ap_pcw_walk_directory_config(apr_pool_t *pconf, server_rec *s,
                                  core_server_config *sconf,
                                  module *modp,
                                  ap_pcw_dir_walker dw, void *data);

void ap_pcw_walk_files_config(apr_pool_t *pconf, server_rec *s,
                              core_dir_config *dconf,
                              module *modp,
                              ap_pcw_dir_walker dw, void *data);

void ap_pcw_walk_default_config(apr_pool_t *pconf, server_rec *s,
                                module *modp,
                                ap_pcw_dir_walker dw, void *data);

void ap_pcw_walk_server_config(apr_pool_t *pconf, server_rec *s,
                               module *modp,
                               ap_pcw_srv_walker sw, void *data);

void ap_pcw_walk_config(apr_pool_t *pconf, server_rec *s,
                        module *modp, void *data,
                        ap_pcw_dir_walker dw, ap_pcw_srv_walker sw);

#endif /* MODPERL_PCW_H */
