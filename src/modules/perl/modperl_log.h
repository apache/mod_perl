#ifndef MODPERL_LOG_H
#define MODPERL_LOG_H

#define MP_FUNC __FUNCTION__ /* XXX: not every cc supports this
                              * sort out later
                              */

#include "modperl_trace.h"

void modperl_trace(char *func, const char *fmt, ...);

void modperl_trace_level_set(char *level);

#endif /* MODPERL_LOG_H */
