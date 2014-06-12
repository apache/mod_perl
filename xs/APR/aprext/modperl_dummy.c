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

/* FIXME: To define extern perl_module to something so libaprext.lib can be
 * linked without error when building against httpd-2.4+. (The symbol is
 * referenced by modperl_apache_compat.h for httpd-2.4+, so must be defined
 * somewhere in that case.)
 */
module AP_MODULE_DECLARE_DATA perl_module = {
    STANDARD20_MODULE_STUFF,
    NULL, /* dir config creater */
    NULL,  /* dir merger --- default is to override */
    NULL, /* server config */
    NULL,  /* merge server config */
    NULL,              /* table of config file commands       */
    NULL,    /* register hooks */
};

/* FIXME: These functions are called from modperl_trace() in libaprext.lib
 * but are normally defined in mod_perl.c which can't be included.
 */

int modperl_is_running(void)
{
    return 0;
}

int modperl_threads_started(void)
{
    return 0;
}

int modperl_threaded_mpm(void)
{
    return 0;
}
