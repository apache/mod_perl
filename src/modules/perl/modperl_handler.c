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

#define set_desc(dtype) \
    MP_TRACE_a_do(if (desc) *desc = modperl_handler_desc_##dtype(idx))

MpAV **modperl_handler_lookup_handlers(modperl_config_dir_t *dcfg,
                                       modperl_config_srv_t *scfg,
                                       modperl_config_req_t *rcfg,
                                       int type, int idx,
                                       const char **desc)
{
    MpAV *av = NULL;

    switch (type) {
      case MP_HANDLER_TYPE_PER_DIR:
        av = dcfg->handlers_per_dir[idx];
        set_desc(per_dir);
        break;
      case MP_HANDLER_TYPE_PER_SRV:
        av = scfg->handlers_per_srv[idx];
        set_desc(per_srv);
        break;
      case MP_HANDLER_TYPE_CONNECTION:
        av = scfg->handlers_connection[idx];
        set_desc(connection);
        break;
      case MP_HANDLER_TYPE_FILES:
        av = scfg->handlers_files[idx];
        set_desc(files);
        break;
      case MP_HANDLER_TYPE_PROCESS:
        av = scfg->handlers_process[idx];
        set_desc(process);
        break;
    };

    return av ? &av : NULL;
}
