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

/* back compat adjustements for older Apache versions
 * BACK_COMPAT_MARKER: make back compat issues easy to find :)
 */

/* use the following format:
 *     #if ! AP_MODULE_MAGIC_AT_LEAST(20020903,4)
 *         [compat code]
 *     #endif
 * and don't forget to insert comments explaining exactly
 * which httpd release allows us to remove the compat code
 */

/* pre-APACHE_2.2.4 */
#if ! AP_MODULE_MAGIC_AT_LEAST(20051115,4)

#define modperl_warn_fallback_http_function(ver, fallback) \
    { \
        dTHX; \
        Perl_warn(aTHX_ "%s() not available until httpd/%s " \
                        "falling back to %s()", \
                  MP_FUNC, ver, fallback); \
    }

/* added in APACHE_2.2.4 */
AP_DECLARE(const char *) ap_get_server_description(void) {
    modperl_warn_fallback_http_function("2.2.4", "ap_get_server_version");
    return ap_get_server_version();
}

AP_DECLARE(const char *) ap_get_server_banner(void) {
    modperl_warn_fallback_http_function("2.2.4", "ap_get_server_version");
    return ap_get_server_version();
}

#endif /* pre-APACHE_2.2.4 */

/* since-APACHE-2.3.0 */
#if AP_MODULE_MAGIC_AT_LEAST(20060905,0)
#define modperl_warn_deprecated_http_function(ver, fallback) \
    { \
        dTHX; \
        Perl_warn(aTHX_ "%s() is deprecated since httpd/%s " \
                        "try using %s() instead", \
                  MP_FUNC, ver, fallback); \
    }

AP_DECLARE(const char *) ap_get_server_version(void) {
    modperl_warn_deprecated_http_function("2.3.0",
        "ap_get_server_(description|banner)");
    return ap_get_server_banner();
}

#endif /* since-APACHE-2.3.0 */
