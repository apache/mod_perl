#include "mod_perl.h"

/*
 * pcw == Parsed Config Walker
 * generic functions for walking parsed config using callbacks
 */

void ap_pcw_walk_location_config(apr_pool_t *pconf, server_rec *s,
                                 core_server_config *sconf,
                                 module *modp,
                                 ap_pcw_dir_walker dw, void *data)
{
    int i;
    ap_conf_vector_t **urls = (ap_conf_vector_t **)sconf->sec_url->elts;

    for (i = 0; i < sconf->sec_url->nelts; i++) {
        core_dir_config *conf =
            ap_get_module_config(urls[i], &core_module);
        void *dir_cfg = ap_get_module_config(urls[i], modp);     
     
        if (!dw(pconf, s, dir_cfg, conf->d, data)) {
            break;
        }
    }
}

void ap_pcw_walk_directory_config(apr_pool_t *pconf, server_rec *s,
                                  core_server_config *sconf,
                                  module *modp,
                                  ap_pcw_dir_walker dw, void *data)
{
    int i;
    ap_conf_vector_t **dirs = (ap_conf_vector_t **)sconf->sec->elts;

    for (i = 0; i < sconf->sec->nelts; i++) {
        core_dir_config *conf =
            ap_get_module_config(dirs[i], &core_module);
        void *dir_cfg = ap_get_module_config(dirs[i], modp);
        if (!dw(pconf, s, dir_cfg, conf->d, data)) {
            break;
        }
    }
}

void ap_pcw_walk_files_config(apr_pool_t *pconf, server_rec *s,
                              core_dir_config *dconf,
                              module *modp,
                              ap_pcw_dir_walker dw, void *data)
{
    int i;
    ap_conf_vector_t **dirs = (ap_conf_vector_t **)dconf->sec->elts;

    for (i = 0; i < dconf->sec->nelts; i++) {
        core_dir_config *conf =
            ap_get_module_config(dirs[i], &core_module);
        void *dir_cfg = ap_get_module_config(dirs[i], modp);
        if (!dw(pconf, s, dir_cfg, conf->d, data)) {
            break;
        }
    }
}

void ap_pcw_walk_default_config(apr_pool_t *pconf, server_rec *s,
                                module *modp,
                                ap_pcw_dir_walker dw, void *data)
{
    core_dir_config *conf = 
        ap_get_module_config(s->lookup_defaults, &core_module);
    void *dir_cfg = 
        ap_get_module_config(s->lookup_defaults, modp);

    dw(pconf, s, dir_cfg, conf->d, data);
}

void ap_pcw_walk_server_config(apr_pool_t *pconf, server_rec *s,
                               module *modp,
                               ap_pcw_srv_walker sw, void *data)
{
    void *cfg = ap_get_module_config(s->module_config, modp);

    if (!cfg) {
        return;
    }

    sw(pconf, s, cfg, data);
}

void ap_pcw_walk_config(apr_pool_t *pconf, server_rec *s,
                        module *modp, void *data,
                        ap_pcw_dir_walker dw, ap_pcw_srv_walker sw)
{
    for (; s; s = s->next) {
        core_dir_config *dconf = 
            ap_get_module_config(s->lookup_defaults,
                                 &core_module);

        core_server_config *sconf =
            ap_get_module_config(s->module_config,
                                 &core_module);

        if (dw) {
            ap_pcw_walk_location_config(pconf, s, sconf, modp, dw, data);
            ap_pcw_walk_directory_config(pconf, s, sconf, modp, dw, data);
            ap_pcw_walk_files_config(pconf, s, dconf, modp, dw, data);
            ap_pcw_walk_default_config(pconf, s, modp, dw, data);
        }
        if (sw) {
            ap_pcw_walk_server_config(pconf, s, modp, sw, data);
        }
    }
}
