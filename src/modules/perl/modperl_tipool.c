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

#ifdef USE_ITHREADS

/*
 * tipool == "thread item pool"
 * this module is intended to provide generic stuctures/functions
 * for managing a "pool" of a given items (data structures) within a threaded
 * process.  at the moment, mod_perl uses this module to manage a pool
 * of PerlInterpreter objects.  it should be quite easy to reuse for
 * other data, such as database connection handles and the like.
 * while it is "generic" it is also tuned for Apache, making use of
 * apr_pool_t and the like, and implementing start/max/{min,max}_spare/
 * max_requests configuration.
 * this is another "proof-of-concept", plenty of room for improvement here
 */

modperl_list_t *modperl_list_new()
{
    modperl_list_t *listp =
        (modperl_list_t *)malloc(sizeof(*listp));
    memset(listp, '\0', sizeof(*listp));
    return listp;
}

volatile modperl_list_t *modperl_list_last(volatile modperl_list_t *list)
{
    while (list->next) {
        list = list->next;
    }

    return list;
}

volatile modperl_list_t *modperl_list_first(volatile modperl_list_t *list)
{
    while (list->prev) {
        list = list->prev;
    }

    return list;
}

volatile modperl_list_t *modperl_list_append(volatile modperl_list_t *list,
                                    modperl_list_t *new_list)
{
    volatile modperl_list_t *last;

    if (new_list)
        new_list->prev = new_list->next = NULL;

    if (!list)
        return (volatile modperl_list_t *)new_list;

    if (!new_list)
        return list;

    last = modperl_list_last(list);

    last->next = new_list;
    new_list->prev = last;
    new_list->next = NULL;
    return list;
}

volatile modperl_list_t *modperl_list_prepend(volatile modperl_list_t *list,
                                     modperl_list_t *new_list)
{
    if (new_list)
        new_list->prev = new_list->next = NULL;
    else
        return list;

    if (!list)
        return (volatile modperl_list_t *)new_list;

    if (list->prev)
        list->prev->next = new_list;

    new_list->next = list;
    new_list->prev = list->prev;
    list->prev = new_list;

    return (volatile modperl_list_t *)new_list;
}

volatile modperl_list_t *modperl_list_remove(volatile modperl_list_t *list,
                                    modperl_list_t *rlist)
{
    volatile modperl_list_t *tmp = list;

    while (tmp) {
        if (tmp != rlist) {
            tmp = tmp->next;
        }
        else {
            if (tmp->prev) {
                tmp->prev->next = tmp->next;
            }
            if (tmp->next) {
                tmp->next->prev = tmp->prev;
            }
            if (list == tmp) {
                list = list->next;
            }
            tmp->prev = tmp->next = NULL;
            break;
        }
    }

#ifdef MP_TRACE
    if (!tmp) {
        /* should never happen */
        MP_TRACE_i(MP_FUNC, "failed to find 0x%lx in list 0x%lx",
                   (unsigned long)rlist, (unsigned long)list);
    }
#endif

    return list;
}

volatile modperl_list_t *modperl_list_remove_data(volatile modperl_list_t *list,
                                                  void *data,
                                                  modperl_list_t **listp)
{
    volatile modperl_list_t *tmp = list;

    while (tmp) {
        if (tmp->data != data) {
            tmp = tmp->next;
        }
        else {
            *listp = tmp;
            if (tmp->prev) {
                tmp->prev->next = tmp->next;
            }
            if (tmp->next) {
                tmp->next->prev = tmp->prev;
            }
            if (list == tmp) {
                list = list->next;
            }
            tmp->prev = tmp->next = NULL;
            break;
        }
    }

    return list;
}

modperl_tipool_t *modperl_tipool_new(apr_pool_t *p,
                                     modperl_tipool_config_t *cfg,
                                     modperl_tipool_vtbl_t *func,
                                     void *data)
{
    modperl_tipool_t *tipool =
        (modperl_tipool_t *)apr_pcalloc(p, sizeof(*tipool));

    tipool->cfg = cfg;
    tipool->func = func;
    tipool->data = data;

    MUTEX_INIT(&tipool->tiplock);
    COND_INIT(&tipool->available);

    return tipool;
}

void modperl_tipool_init(modperl_tipool_t *tipool)
{
    int i;
    for (i=0; i<tipool->cfg->start; i++) {
        void *item =
            (*tipool->func->tipool_sgrow)(tipool, tipool->data);

        modperl_tipool_add(tipool, item);
    }

    MP_TRACE_i(MP_FUNC, "start=%d, max=%d, min_spare=%d, max_spare=%d",
               tipool->cfg->start, tipool->cfg->max,
               tipool->cfg->min_spare, tipool->cfg->max_spare);

}

void modperl_tipool_destroy(modperl_tipool_t *tipool)
{
    while (tipool->idle) {
        volatile modperl_list_t *listp;

        if (tipool->func->tipool_destroy) {
            (*tipool->func->tipool_destroy)(tipool, tipool->data,
                                            tipool->idle->data);
        }
        tipool->size--;
        listp = tipool->idle->next;
        free(tipool->idle);
        tipool->idle = listp;
    }

    if (tipool->busy) {
        MP_TRACE_i(MP_FUNC, "ERROR: %d items still in use",
                   tipool->in_use);
    }

    MUTEX_DESTROY(&tipool->tiplock);
    COND_DESTROY(&tipool->available);
}

void modperl_tipool_add(modperl_tipool_t *tipool, void *data)
{
    modperl_list_t *listp = modperl_list_new();

    listp->data = data;

    /* assuming tipool->tiplock has already been acquired */

    tipool->idle = modperl_list_append(tipool->idle, listp);

    tipool->size++;

    MP_TRACE_i(MP_FUNC, "added 0x%lx (size=%d)",
               (unsigned long)listp, tipool->size);
}

void modperl_tipool_remove(modperl_tipool_t *tipool, modperl_list_t *listp)
{
    /* assuming tipool->tiplock has already been acquired */

    tipool->idle = modperl_list_remove(tipool->idle, listp);

    tipool->size--;
    MP_TRACE_i(MP_FUNC, "removed 0x%lx (size=%d)",
               (unsigned long)listp, tipool->size);

    free(listp);
}

modperl_list_t *modperl_tipool_pop(modperl_tipool_t *tipool)
{


    modperl_tipool_lock(tipool);
    volatile modperl_list_t *head = tipool->idle;

    if (!head) {
    START:
        if (tipool->size < tipool->cfg->max) {
            if (tipool->func->tipool_rgrow) {
                MP_TRACE_i(MP_FUNC,
                       "growing pool: min_spare=%d, %d of %d in use",
                       tipool->cfg->min_spare, tipool->in_use,
                       tipool->size);
                void *item =
                    (*tipool->func->tipool_rgrow)(tipool,
                                              tipool->data);
                modperl_tipool_add(tipool, item);
            }
        }
        else
            modperl_tipool_wait(tipool);

        head = tipool->idle;
    }

    /* XXX: this should never happen */
    if (!head) {
        MP_TRACE_i(MP_FUNC, "PANIC: no items available, %d of %d in use",
                   tipool->in_use, tipool->size);
        goto START;
    }
    tipool->idle = modperl_list_remove(tipool->idle, head);
    tipool->busy = modperl_list_append(tipool->busy, head);

    tipool->in_use++;
    modperl_tipool_unlock(tipool);
    return (modperl_list_t *)head;
}

static void modperl_tipool_putback_base(modperl_tipool_t *tipool,
                                        modperl_list_t *listp,
                                        void *data,
                                        int num_requests)
{
    modperl_tipool_lock(tipool);
    /* remove from busy list, add back to idle */
    /* XXX: option to sort list, e.g. on num_requests */

    if (listp) {
        tipool->busy = modperl_list_remove(tipool->busy, listp);
    }
    else {
        tipool->busy = modperl_list_remove_data(tipool->busy, data, &listp);
    }

    tipool->in_use--;


#ifdef MP_TRACE
    if (!tipool->busy && tipool->func->tipool_dump) {
        MP_TRACE_i(MP_FUNC, "all items idle:");
        MP_TRACE_i_do((*tipool->func->tipool_dump)(tipool,
                                                   tipool->data,
                                                   tipool->idle));
    }
#endif

    if (!listp) {
        MP_TRACE_i(MP_FUNC, "what happened to listp?");
        goto MANAGE_TIPOOL;
    }

    MP_TRACE_i(MP_FUNC, "0x%lx now available (%d in use, %d running)",
               (unsigned long)listp->data, tipool->in_use, tipool->size);

    tipool->idle = modperl_list_prepend(tipool->idle, listp);
    modperl_tipool_signal(tipool);
    /* XXX: this management should probably be happening elsewhere
     * like in a thread spawned at startup
     */
 MANAGE_TIPOOL:
    if (tipool->func->tipool_destroy) {
        while (tipool->size - tipool->in_use > tipool->cfg->max_spare) {
            if (tipool->idle && tipool->idle->next) {
                listp = modperl_list_last(tipool->idle->next);
                if (listp) {
                    MP_TRACE_i(MP_FUNC,
                       "shrinking pool: destroying 0x%lx, max_spare=%d, %d of %d in use",
                               (unsigned long)listp->data, tipool->cfg->max_spare, tipool->in_use,
                               tipool->size);
                    void *data = listp->data;
                    modperl_tipool_remove(tipool, listp);
                    (*tipool->func->tipool_destroy)(tipool, tipool->data, data);
                }
                else
                    break;
            }
            else
                break;
        }
    }
    if (tipool->func->tipool_rgrow) {
        if (tipool->size < tipool->cfg->max && tipool->size - tipool->in_use < tipool->cfg->min_spare) {
            MP_TRACE_i(MP_FUNC,
                       "growing pool: min_spare=%d, %d of %d in use",
                       tipool->cfg->min_spare, tipool->in_use,
                       tipool->size);
             void *item =
                (*tipool->func->tipool_rgrow)(tipool,
                                              tipool->data);
             modperl_tipool_add(tipool, item);
             modperl_tipool_signal(tipool);
        }
    }
    modperl_tipool_unlock(tipool);
}

/* _data functions are so structures (e.g. modperl_interp_t) don't
 * need to maintain a pointer back to the modperl_list_t
 */
void modperl_tipool_putback_data(modperl_tipool_t *tipool,
                                 void *data,
                                 int num_requests)
{
    modperl_tipool_putback_base(tipool, NULL, data, num_requests);
}

void modperl_tipool_putback(modperl_tipool_t *tipool,
                            modperl_list_t *listp,
                            int num_requests)
{
    modperl_tipool_putback_base(tipool, listp, NULL, num_requests);
}

#endif /* USE_ITHREADS */

/*
 * Local Variables:
 * c-basic-offset: 4
 * indent-tabs-mode: nil
 * End:
 */
