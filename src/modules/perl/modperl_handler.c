#include "mod_perl.h"

modperl_handler_t *modperl_handler_new(apr_pool_t *p, const char *name)
{
    modperl_handler_t *handler = 
        (modperl_handler_t *)apr_pcalloc(p, sizeof(*handler));

    handler->name = name;
    MP_TRACE_h(MP_FUNC, "new handler %s\n", handler->name);

    return handler;
}

modperl_handler_t *modperl_handler_dup(apr_pool_t *p,
                                       modperl_handler_t *h)
{
    MP_TRACE_h(MP_FUNC, "dup handler %s\n", h->name);
    return modperl_handler_new(p, h->name);
}

void modperl_handler_make_args(pTHX_ AV **avp, ...)
{
    va_list args;

    if (!*avp) {
        *avp = newAV(); /* XXX: cache an intialized AV* per-request */
    }

    va_start(args, avp);

    for (;;) {
        char *classname = va_arg(args, char *);
        void *ptr;
        SV *sv;
            
        if (classname == NULL) {
            break;
        }

        ptr = va_arg(args, void *);

        switch (*classname) {
          case 'I':
            if (strEQ(classname, "IV")) {
                sv = ptr ? newSViv((IV)ptr) : &PL_sv_undef;
                break;
            }
          case 'P':
            if (strEQ(classname, "PV")) {
                sv = ptr ? newSVpv((char *)ptr, 0) : &PL_sv_undef;
                break;
            }
          default:
            sv = modperl_ptr2obj(aTHX_ classname, ptr);
            break;
        }

        av_push(*avp, sv);
    }

    va_end(args);
}
