/* Copyright 2003-2005 The Apache Software Foundation
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

#include "modperl_module.h"

static MP_INLINE
SV *mpxs_Apache2__CmdParms_info(pTHX_ cmd_parms *parms)
{
    const char *data = ((modperl_module_cmd_data_t *)parms->info)->cmd_data;

    if (data) {
        return newSVpv(data, 0);
    }

    return &PL_sv_undef;    
}

static MP_INLINE
void mpxs_Apache2__CmdParms_add_config(pTHX_ cmd_parms *parms, SV *lines)
{
    const char *errmsg = modperl_config_insert_parms(aTHX_ parms, lines);
    if (errmsg) {
        Perl_croak(aTHX_ "$parms->add_config() has failed: %s", errmsg);
    }
}
