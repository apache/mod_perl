/* Copyright 2003-2004 The Apache Software Foundation
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

#ifndef MODPERL_APR_COMPAT_H
#define MODPERL_APR_COMPAT_H

/* back compat adjustements for older libapr versions */

/* BACK_COMPAT_MARKER: make back compat issues easy to find :) */

/* use the following format:
 *     #if ! AP_MODULE_MAGIC_AT_LEAST(20020903,4)
 *         [compat code]
 *     #endif
 * and don't forget to insert comments explaining exactly
 * which httpd release allows us to remove the compat code
 */

/* apr_filetype_e entries rename */

#ifndef APR_FILETYPE_NOFILE
#define APR_FILETYPE_NOFILE  APR_NOFILE
#endif
#ifndef APR_FILETYPE_REG
#define APR_FILETYPE_REG     APR_REG
#endif
#ifndef APR_FILETYPE_DIR
#define APR_FILETYPE_DIR     APR_DIR
#endif
#ifndef APR_FILETYPE_CHR
#define APR_FILETYPE_CHR     APR_CHR
#endif
#ifndef APR_FILETYPE_BLK
#define APR_FILETYPE_BLK     APR_BLK
#endif
#ifndef APR_FILETYPE_PIPE
#define APR_FILETYPE_PIPE    APR_PIPE
#endif
#ifndef APR_FILETYPE_LNK
#define APR_FILETYPE_LNK     APR_LNK
#endif
#ifndef APR_FILETYPE_SOCK
#define APR_FILETYPE_SOCK    APR_SOCK
#endif
#ifndef APR_FILETYPE_UNKFILE
#define APR_FILETYPE_UNKFILE APR_UNKFILE
#endif


/* apr file permissions group rename (has no enum) */

#if defined(APR_USETID) && !defined(APR_FILEPROT_USETID)
#define APR_FILEPROT_USETID     APR_USETID
#endif
#ifndef APR_FILEPROT_UREAD
#define APR_FILEPROT_UREAD      APR_UREAD
#endif
#ifndef APR_FILEPROT_UWRITE
#define APR_FILEPROT_UWRITE     APR_UWRITE
#endif
#ifndef APR_FILEPROT_UEXECUTE
#define APR_FILEPROT_UEXECUTE   APR_UEXECUTE
#endif
#if defined(APR_GSETID) && !defined(APR_FILEPROT_GSETID)
#define APR_FILEPROT_GSETID     APR_GSETID
#endif
#ifndef APR_FILEPROT_GREAD
#define APR_FILEPROT_GREAD      APR_GREAD
#endif
#ifndef APR_FILEPROT_GWRITE
#define APR_FILEPROT_GWRITE     APR_GWRITE
#endif
#ifndef APR_FILEPROT_GEXECUTE
#define APR_FILEPROT_GEXECUTE   APR_GEXECUTE
#endif
#if defined(APR_WSTICKY) && !defined(APR_FILEPROT_WSTICKY)
#define APR_FILEPROT_WSTICKY    APR_WSTICKY
#endif
#ifndef APR_FILEPROT_WREAD
#define APR_FILEPROT_WREAD      APR_WREAD
#endif
#ifndef APR_FILEPROT_WWRITE
#define APR_FILEPROT_WWRITE     APR_WWRITE
#endif
#ifndef APR_FILEPROT_WEXECUTE
#define APR_FILEPROT_WEXECUTE   APR_WEXECUTE
#endif
#ifndef APR_FILEPROT_OS_DEFAULT
#define APR_FILEPROT_OS_DEFAULT APR_OS_DEFAULT
#endif
/* APR_FILEPROT_FILE_SOURCE_PERMS seems to have only an internal apr
 * use */




#endif /* MODPERL_APR_COMPAT_H */
