/* Copyright 2002-2004 The Apache Software Foundation
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

#define apr_thread_mutex_DESTROY apr_thread_mutex_destroy

static MP_INLINE
apr_thread_mutex_t *mpxs_apr_thread_mutex_create(pTHX_ SV *classname,
                                                 apr_pool_t *pool,
                                                 unsigned int flags)
{
    apr_thread_mutex_t *mutex = NULL;
    (void)apr_thread_mutex_create(&mutex, flags, pool);
    return mutex;
}
