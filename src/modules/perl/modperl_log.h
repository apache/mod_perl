#ifndef MODPERL_LOG_H
#define MODPERL_LOG_H

#define MP_FUNC __FUNCTION__ /* XXX: not every cc supports this
                              * sort out later
                              */

#include "modperl_trace.h"

#ifdef _PTHREAD_H
#define modperl_thread_self() pthread_self()
#else
#define modperl_thread_self() 0
#endif

#define MP_TIDF \
(unsigned long)modperl_thread_self()

void modperl_trace(char *func, const char *fmt, ...);

void modperl_trace_level_set(char *level);

#endif /* MODPERL_LOG_H */
