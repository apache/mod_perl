/* Copyright 2001-2004 The Apache Software Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

static MP_INLINE
int mpxs_Apache__Server_push_handlers(pTHX_ server_rec *s,
                                      const char *name,
                                      SV *sv)
{
    return modperl_handler_perl_add_handlers(aTHX_
                                             NULL, NULL, s,
                                             s->process->pconf,
                                             name, sv,
                                             MP_HANDLER_ACTION_PUSH);

}

static MP_INLINE
int mpxs_Apache__Server_set_handlers(pTHX_ server_rec *s,
                                     const char *name,
                                     SV *sv)
{
    return modperl_handler_perl_add_handlers(aTHX_
                                             NULL, NULL, s,
                                             s->process->pconf,
                                             name, sv,
                                             MP_HANDLER_ACTION_SET);
}

static MP_INLINE
SV *mpxs_Apache__Server_get_handlers(pTHX_ server_rec *s,
                                     const char *name)
{
    MpAV **handp =
        modperl_handler_get_handlers(NULL, NULL, s,
                                     s->process->pconf, name,
                                     MP_HANDLER_ACTION_GET);

    return modperl_handler_perl_get_handlers(aTHX_ handp,
                                             s->process->pconf);
}

#define mpxs_Apache__Server_dir_config(s, key, sv_val) \
    modperl_dir_config(aTHX_ NULL, s, key, sv_val)

#define mpxs_Apache_server(classname) \
modperl_global_get_server_rec()

#define mpxs_Apache__Server_server_root_relative(sv, fname) \
    modperl_server_root_relative(aTHX_ sv, fname);

#define mpxs_Apache_server_root_relative(sv, fname) \
    modperl_server_root_relative(aTHX_ sv, fname);

static MP_INLINE
int mpxs_Apache__Server_is_perl_option_enabled(pTHX_ server_rec *s,
                                               const char *name)
{
    return modperl_config_is_perl_option_enabled(aTHX_ NULL, s, name);
}


static MP_INLINE
void mpxs_Apache__Server_add_config(pTHX_ server_rec *s, SV *lines)
{
    const char *errmsg = modperl_config_insert_server(aTHX_ s, lines);
    if (errmsg) {
        Perl_croak(aTHX_ "$s->add_config() has failed: %s", errmsg);
    }
}

static void mpxs_Apache__ServerUtil_BOOT(pTHX)
{
    newCONSTSUB(PL_defstash, "Apache::server_root",
                newSVpv(ap_server_root, 0));

    newCONSTSUB(PL_defstash, "Apache::get_server_built",
                newSVpv(ap_get_server_built(), 0));

    newCONSTSUB(PL_defstash, "Apache::get_server_version",
                newSVpv(ap_get_server_version(), 0));
}
