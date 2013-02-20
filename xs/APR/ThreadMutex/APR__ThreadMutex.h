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

#define apr_thread_mutex_DESTROY apr_thread_mutex_destroy

static MP_INLINE
SV *mpxs_apr_thread_mutex_create(pTHX_ SV *classname, SV *p_sv,
                                 unsigned int flags)
{
    apr_pool_t *p = mp_xs_sv2_APR__Pool(p_sv);
    apr_thread_mutex_t *mutex = NULL;
    SV *mutex_sv;
    (void)apr_thread_mutex_create(&mutex, flags, p);
    mutex_sv = sv_setref_pv(newSV(0), "APR::ThreadMutex", (void*)mutex);
    mpxs_add_pool_magic(mutex_sv, p_sv);
    return mutex_sv;
}
