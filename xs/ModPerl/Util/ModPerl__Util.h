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

static MP_INLINE void mpxs_ModPerl__Util_untaint(pTHX_ I32 items,
                                                 SV **MARK, SV **SP)
{
    if (!PL_tainting) {
        return;
    }
    while (MARK <= SP) {
        sv_untaint(*MARK++);
    }
}

#define mpxs_ModPerl__Util_exit(status) modperl_perl_exit(aTHX_ status)

#define mpxs_ModPerl__Util_current_callback \
        modperl_callback_current_callback_get



