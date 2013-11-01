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

#ifndef MODPERL_INTERP_H
#define MODPERL_INTERP_H

void modperl_interp_init(server_rec *s, apr_pool_t *p,
                         PerlInterpreter *perl);

apr_status_t modperl_interp_cleanup(void *data);

#ifdef USE_ITHREADS

modperl_interp_t *modperl_thx_interp_get(PerlInterpreter *thx);
void modperl_thx_interp_set(PerlInterpreter *thx, modperl_interp_t *interp);

const char *modperl_interp_scope_desc(modperl_interp_scope_e scope);

void modperl_interp_clone_init(modperl_interp_t *interp);

modperl_interp_t *modperl_interp_new(modperl_interp_pool_t *mip,
                                     PerlInterpreter *perl);

void modperl_interp_destroy(modperl_interp_t *interp);

modperl_interp_t *modperl_interp_get(server_rec *s);

apr_status_t modperl_interp_unselect(void *data);

modperl_interp_t *modperl_interp_pool_get(apr_pool_t *p);

void modperl_interp_pool_set(apr_pool_t *p,
                             modperl_interp_t *interp);

modperl_interp_t *modperl_interp_pool_select(apr_pool_t *p,
                                             server_rec *s);

modperl_interp_t *modperl_interp_select(request_rec *r, conn_rec *c,
                                        server_rec *s);

#define MP_pINTERP pTHX; modperl_interp_t *interp = NULL

#define MP_dINTERP(r, c, s)                                             \
    interp = modperl_interp_select(r, c, s);                            \
    aTHX = interp->perl

#ifdef MP_DEBUG
#define MP_dINTERP_POOL(p, s)                                           \
    MP_TRACE_i(MP_FUNC, "selecting interp: p=%pp, s=%pp", (p), (s));    \
    interp = modperl_interp_pool_select(p, s);                          \
    MP_TRACE_i(MP_FUNC, "  --> got (0x%pp)->refcnt=%d",                 \
               interp, interp->refcnt);                                 \
    aTHX = interp->perl
#else  /* MP_DEBUG */
#define MP_dINTERP_POOL(p, s)                                           \
    interp = modperl_interp_pool_select(p, s);                          \
    aTHX = interp->perl
#endif

#ifdef MP_DEBUG
#define MP_INTERP_PUTBACK(interp)                                       \
    MP_TRACE_i(MP_FUNC, "unselecting interp: (0x%pp)->refcnt=%ld",      \
               (interp), (interp)->refcnt);                             \
    modperl_interp_unselect(interp);                                    \
    interp = NULL;                                                      \
    aTHX = NULL;                                                        \
    PERL_SET_CONTEXT(NULL)
#else  /* MP_DEBUG */
#define MP_INTERP_PUTBACK(interp)                                       \
    modperl_interp_unselect(interp)
#endif

# if 1
/* ideally we should be able to reset interp and aTHX to NULL after
 * unselecting the interpreter. Unfortunately that does not work, yet */
#undef MP_INTERP_PUTBACK
#define MP_INTERP_PUTBACK(interp)                                       \
    MP_TRACE_i(MP_FUNC, "unselecting interp: (0x%pp)->refcnt=%ld",      \
               (interp), (interp)->refcnt);                             \
    modperl_interp_unselect(interp)
# endif  /* 0 */

#define MP_INTERP_REFCNT_inc(interp) (interp)->refcnt++

#define MP_INTERP_REFCNT_dec(interp) MP_INTERP_PUTBACK(interp)

#define MP_aTHX aTHX

apr_status_t modperl_interp_pool_destroy(void *data);

typedef apr_status_t (*modperl_interp_mip_walker_t)(pTHX_
                                                    modperl_interp_pool_t *mip,
                                                    void *data);

void modperl_interp_mip_walk(PerlInterpreter *current_perl,
                             PerlInterpreter *parent_perl,
                             modperl_interp_pool_t *mip,
                             modperl_interp_mip_walker_t walker,
                             void *data);

void modperl_interp_mip_walk_servers(PerlInterpreter *current_perl,
                                     server_rec *base_server,
                                     modperl_interp_mip_walker_t walker,
                                     void *data);
#else

#define MP_pINTERP dNOOP

#define MP_dINTERP(r, c, s) NOOP

#define MP_dINTERP_POOL(p, s) NOOP

#define MP_INTERP_PUTBACK(interp) NOOP

#define MP_INTERP_REFCNT_inc(interp) NOOP

#define MP_INTERP_REFCNT_dec(interp) NOOP

#define MP_aTHX 0

#endif /* USE_ITHREADS */

#endif /* MODPERL_INTERP_H */

/*
 * Local Variables:
 * c-basic-offset: 4
 * indent-tabs-mode: nil
 * End:
 */
