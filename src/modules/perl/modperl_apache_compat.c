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

#include "mod_perl.h"

/* back compat adjustements for older Apache versions
 * BACK_COMPAT_MARKER: make back compat issues easy to find :)
 */

/* pre-APR_0_9_5 (APACHE_2_0_47)
 * both 2.0.46 and 2.0.47 shipped with 0.9.4 -
 * we need the one that shipped with 2.0.47,
   which is major mmn 20020903, minor mmn 4 */
#if ! AP_MODULE_MAGIC_AT_LEAST(20020903,4)

/* added in APACHE_2_0_47/APR_0_9_4 - duplicated here for 2.0.46.
 * I'd rather not duplicate it, but we use apr_table_compress
 * in the directive merge routines, so it's either duplicate it
 * here, recode the compress logic there, or drop 2.0.46 support
 */

#define TABLE_HASH_SIZE 32

struct apr_table_t {
    apr_array_header_t a;
#ifdef MAKE_TABLE_PROFILE
    /** Who created the array. */
    void *creator;
#endif
    apr_uint32_t index_initialized;
    int index_first[TABLE_HASH_SIZE];
    int index_last[TABLE_HASH_SIZE];
};

static apr_table_entry_t **table_mergesort(apr_pool_t *pool,
                                           apr_table_entry_t **values, int n)
{
    /* Bottom-up mergesort, based on design in Sedgewick's "Algorithms
     * in C," chapter 8
     */
    apr_table_entry_t **values_tmp =
        (apr_table_entry_t **)apr_palloc(pool, n * sizeof(apr_table_entry_t*));
    int i;
    int blocksize;

    /* First pass: sort pairs of elements (blocksize=1) */
    for (i = 0; i + 1 < n; i += 2) {
        if (strcasecmp(values[i]->key, values[i + 1]->key) > 0) {
            apr_table_entry_t *swap = values[i];
            values[i] = values[i + 1];
            values[i + 1] = swap;
        }
    }

    /* Merge successively larger blocks */
    blocksize = 2;
    while (blocksize < n) {
        apr_table_entry_t **dst = values_tmp;
        int next_start;
        apr_table_entry_t **swap;

        /* Merge consecutive pairs blocks of the next blocksize.
         * Within a block, elements are in sorted order due to
         * the previous iteration.
         */
        for (next_start = 0; next_start + blocksize < n;
             next_start += (blocksize + blocksize)) {

            int block1_start = next_start;
            int block2_start = block1_start + blocksize;
            int block1_end = block2_start;
            int block2_end = block2_start + blocksize;
            if (block2_end > n) {
                /* The last block may be smaller than blocksize */
                block2_end = n;
            }
            for (;;) {

                /* Merge the next two blocks:
                 * Pick the smaller of the next element from
                 * block 1 and the next element from block 2.
                 * Once either of the blocks is emptied, copy
                 * over all the remaining elements from the
                 * other block
                 */
                if (block1_start == block1_end) {
                    for (; block2_start < block2_end; block2_start++) {
                        *dst++ = values[block2_start];
                    }
                    break;
                }
                else if (block2_start == block2_end) {
                    for (; block1_start < block1_end; block1_start++) {
                        *dst++ = values[block1_start];
                    }
                    break;
                }
                if (strcasecmp(values[block1_start]->key,
                               values[block2_start]->key) > 0) {
                    *dst++ = values[block2_start++];
                }
                else {
                    *dst++ = values[block1_start++];
                }
            }
        }

        /* If n is not a multiple of 2*blocksize, some elements
         * will be left over at the end of the array.
         */
        for (i = dst - values_tmp; i < n; i++) {
            values_tmp[i] = values[i];
        }

        /* The output array of this pass becomes the input
         * array of the next pass, and vice versa
         */
        swap = values_tmp;
        values_tmp = values;
        values = swap;

        blocksize += blocksize;
    }

    return values;
}
void apr_table_compress(apr_table_t *t, unsigned flags)
{
    apr_table_entry_t **sort_array;
    apr_table_entry_t **sort_next;
    apr_table_entry_t **sort_end;
    apr_table_entry_t *table_next;
    apr_table_entry_t **last;
    int i;
    int dups_found;

    if (t->a.nelts <= 1) {
        return;
    }

    /* Copy pointers to all the table elements into an
     * array and sort to allow for easy detection of
     * duplicate keys
     */
    sort_array = (apr_table_entry_t **)
        apr_palloc(t->a.pool, t->a.nelts * sizeof(apr_table_entry_t*));
    sort_next = sort_array;
    table_next = (apr_table_entry_t *)t->a.elts;
    i = t->a.nelts;
    do {
        *sort_next++ = table_next++;
    } while (--i);

    /* Note: the merge is done with mergesort instead of quicksort
     * because mergesort is a stable sort and runs in n*log(n)
     * time regardless of its inputs (quicksort is quadratic in
     * the worst case)
     */
    sort_array = table_mergesort(t->a.pool, sort_array, t->a.nelts);

    /* Process any duplicate keys */
    dups_found = 0;
    sort_next = sort_array;
    sort_end = sort_array + t->a.nelts;
    last = sort_next++;
    while (sort_next < sort_end) {
        if (((*sort_next)->key_checksum == (*last)->key_checksum) &&
            !strcasecmp((*sort_next)->key, (*last)->key)) {
            apr_table_entry_t **dup_last = sort_next + 1;
            dups_found = 1;
            while ((dup_last < sort_end) &&
                   ((*dup_last)->key_checksum == (*last)->key_checksum) &&
                   !strcasecmp((*dup_last)->key, (*last)->key)) {
                dup_last++;
            }
            dup_last--; /* Elements from last through dup_last, inclusive,
                         * all have the same key
                         */
            if (flags == APR_OVERLAP_TABLES_MERGE) {
                apr_size_t len = 0;
                apr_table_entry_t **next = last;
                char *new_val;
                char *val_dst;
                do {
                    len += strlen((*next)->val);
                    len += 2; /* for ", " or trailing null */
                } while (++next <= dup_last);
                new_val = (char *)apr_palloc(t->a.pool, len);
                val_dst = new_val;
                next = last;
                for (;;) {
                    strcpy(val_dst, (*next)->val);
                    val_dst += strlen((*next)->val);
                    next++;
                    if (next > dup_last) {
                        *val_dst = 0;
                        break;
                    }
                    else {
                        *val_dst++ = ',';
                        *val_dst++ = ' ';
                    }
                }
                (*last)->val = new_val;
            }
            else { /* overwrite */
                (*last)->val = (*dup_last)->val;
            }
            do {
                (*sort_next)->key = NULL;
            } while (++sort_next <= dup_last);
        }
        else {
            last = sort_next++;
        }
    }

    /* Shift elements to the left to fill holes left by removing duplicates */
    if (dups_found) {
        apr_table_entry_t *src = (apr_table_entry_t *)t->a.elts;
        apr_table_entry_t *dst = (apr_table_entry_t *)t->a.elts;
        apr_table_entry_t *last_elt = src + t->a.nelts;
        do {
            if (src->key) {
                *dst++ = *src;
            }
        } while (++src < last_elt);
        t->a.nelts -= (last_elt - dst);
    }

    /* XXX mod_perl: remove to avoid more code duplication.
     * XXX makes us slower on 2.0.46
     */
    /* table_reindex(t); */
}

#endif /* pre-APR_0_9_5 (APACHE_2_0_47) */
