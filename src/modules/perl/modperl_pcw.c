/* Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "mod_perl.h"

/*
 * pcw == Parsed Config Walker
 * generic functions for walking parsed config using callbacks
 */

void ap_pcw_walk_location_config(apr_pool_t *pconf, server_rec *s,
                                 core_server_config *sconf,
                                 module *modp,
                                 ap_pcw_dir_cb_t dir_cb, void *data)
{
    int i;
    ap_conf_vector_t **urls;

    if( !sconf->sec_url ) return;

    urls = (ap_conf_vector_t **)sconf->sec_url->elts;

    for (i = 0; i < sconf->sec_url->nelts; i++) {
        core_dir_config *conf =
            ap_get_module_config(urls[i], &core_module);
        void *dir_cfg = ap_get_module_config(urls[i], modp);

        if (!dir_cb(pconf, s, dir_cfg, conf->d, data)) {
            break;
        }
    }
}

void ap_pcw_walk_directory_config(apr_pool_t *pconf, server_rec *s,
                                  core_server_config *sconf,
                                  module *modp,
                                  ap_pcw_dir_cb_t dir_cb, void *data)
{
    int i;
    ap_conf_vector_t **dirs;

    if( !sconf->sec_dir ) return;

    dirs = (ap_conf_vector_t **)sconf->sec_dir->elts;

    for (i = 0; i < sconf->sec_dir->nelts; i++) {
        core_dir_config *conf =
            ap_get_module_config(dirs[i], &core_module);
        void *dir_cfg = ap_get_module_config(dirs[i], modp);

        if (!dir_cb(pconf, s, dir_cfg, conf->d, data)) {
            break;
        }
    }
}

void ap_pcw_walk_files_config(apr_pool_t *pconf, server_rec *s,
                              core_dir_config *dconf,
                              module *modp,
                              ap_pcw_dir_cb_t dir_cb, void *data)
{
    int i;
    ap_conf_vector_t **dirs;

    if( !dconf->sec_file ) return;

    dirs = (ap_conf_vector_t **)dconf->sec_file->elts;

    for (i = 0; i < dconf->sec_file->nelts; i++) {
        core_dir_config *conf =
            ap_get_module_config(dirs[i], &core_module);
        void *dir_cfg = ap_get_module_config(dirs[i], modp);

        if (!dir_cb(pconf, s, dir_cfg, conf->d, data)) {
            break;
        }
    }
}

void ap_pcw_walk_default_config(apr_pool_t *pconf, server_rec *s,
                                module *modp,
                                ap_pcw_dir_cb_t dir_cb, void *data)
{
    core_dir_config *conf =
        ap_get_module_config(s->lookup_defaults, &core_module);
    void *dir_cfg =
        ap_get_module_config(s->lookup_defaults, modp);

    dir_cb(pconf, s, dir_cfg, conf->d, data);
}

void ap_pcw_walk_server_config(apr_pool_t *pconf, server_rec *s,
                               module *modp,
                               ap_pcw_srv_cb_t srv_cb, void *data)
{
    void *cfg = ap_get_module_config(s->module_config, modp);

    if (!cfg) {
        return;
    }

    srv_cb(pconf, s, cfg, data);
}

void ap_pcw_walk_config(apr_pool_t *pconf, server_rec *s,
                        module *modp, void *data,
                        ap_pcw_dir_cb_t dir_cb, ap_pcw_srv_cb_t srv_cb)
{
    for (; s; s = s->next) {
        core_dir_config *dconf =
            ap_get_module_config(s->lookup_defaults,
                                 &core_module);

        core_server_config *sconf =
            ap_get_module_config(s->module_config,
                                 &core_module);

        if (dir_cb) {
            ap_pcw_walk_location_config(pconf, s, sconf, modp, dir_cb, data);
            ap_pcw_walk_directory_config(pconf, s, sconf, modp, dir_cb, data);
            ap_pcw_walk_files_config(pconf, s, dconf, modp, dir_cb, data);
            ap_pcw_walk_default_config(pconf, s, modp, dir_cb, data);
        }

        if (srv_cb) {
            ap_pcw_walk_server_config(pconf, s, modp, srv_cb, data);
        }
    }
}
