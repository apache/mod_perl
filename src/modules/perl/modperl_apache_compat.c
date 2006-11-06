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
