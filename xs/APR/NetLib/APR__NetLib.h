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
apr_ipsubnet_t *mpxs_apr_ipsubnet_create(pTHX_ SV *classname, apr_pool_t *p,
                                         const char *ipstr,
                                         const char *mask_or_numbits)
{
    apr_status_t status;
    apr_ipsubnet_t *ipsub = NULL;
    status = apr_ipsubnet_create(&ipsub, ipstr, mask_or_numbits, p);
    if (status != APR_SUCCESS) {
        return NULL;
    }
    return ipsub;
}
