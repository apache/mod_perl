#include "mod_perl.h"

/* re-use the ->unset field to determine options type */
#define MpOptionsType(o)        (o)->unset
#define MpOptionsTypeDir(o)     MpOptionsType(o) == MpDir_f_UNSET
#define MpOptionsTypeSrv(o)     MpOptionsType(o) == MpSrv_f_UNSET
#define MpOptionsTypeDir_set(o) MpOptionsType(o) = MpDir_f_UNSET
#define MpOptionsTypeSrv_set(o) MpOptionsType(o) = MpSrv_f_UNSET
#define MP_OPTIONS_TYPE_DIR     MpDir_f_UNSET
#define MP_OPTIONS_TYPE_SRV     MpSrv_f_UNSET

static modperl_opts_t flags_lookup(modperl_options_t *o,
                                   const char *str)
{
    switch (MpOptionsType(o)) {
      case MP_OPTIONS_TYPE_SRV:
        return modperl_flags_lookup_srv(str);
      case MP_OPTIONS_TYPE_DIR:
        return modperl_flags_lookup_dir(str);
      default:
        return '\0';
    };
}

static const char *type_lookup(modperl_options_t *o)
{
    switch (MpOptionsType(o)) {
      case MP_OPTIONS_TYPE_SRV:
        return "server";
      case MP_OPTIONS_TYPE_DIR:
        return "directory";
      default:
        return "unknown";
    };
}

modperl_options_t *modperl_options_new(apr_pool_t *p, int type)
{
    modperl_options_t *options = 
        (modperl_options_t *)apr_pcalloc(p, sizeof(*options));

    options->opts = options->unset = 
        (type == MpSrvType ? MpSrv_f_UNSET : MpDir_f_UNSET);

    return options;
}

const char *modperl_options_set(apr_pool_t *p, modperl_options_t *o,
                                const char *str)
{
    modperl_opts_t opt;
    char action = '\0';
    const char *error = NULL;

    if (*str == '+' || *str == '-') {
        action = *(str++);
    }

    if (!(opt = flags_lookup(o, str))) {
        error = apr_pstrcat(p, "Invalid per-", type_lookup(o),
                            " PerlOption: ", str, NULL);

        if (MpOptionsTypeDir(o)) {
            modperl_options_t dummy;
            MpOptionsTypeSrv_set(&dummy);

            if (flags_lookup(&dummy, str)) {
                error = apr_pstrcat(p, error,
                                    " (only allowed per-server)",
                                    NULL);
            }
        }

        return error;
    }
    
    if (action == '-') {
        o->opts_remove |= opt;
        o->opts_add &= ~opt;
        o->opts &= ~opt;
    }
    else if (action == '+') {
        o->opts_add |= opt;
        o->opts_remove &= ~opt;
        o->opts |= opt;
    }
    else {
        o->opts |= opt;
    }

    return NULL;
}

modperl_options_t *modperl_options_merge(apr_pool_t *p,
                                         modperl_options_t *base,
                                         modperl_options_t *add)
{
    modperl_options_t *conf = modperl_options_new(p, 0);
    memcpy((char *)conf, (const char *)base, sizeof(*base));

    if (add->opts & add->unset) {
        /* there was no explicit setting of add->opts, so we merge
         * preserve the invariant (opts_add & opts_remove) == 0
         */
        conf->opts_add =
            (conf->opts_add & ~add->opts_remove) | add->opts_add;
        conf->opts_remove =
            (conf->opts_remove & ~add->opts_add) | add->opts_remove;
        conf->opts =
            (conf->opts & ~conf->opts_remove) | conf->opts_add;
    }
    else {
        /* otherwise we just copy, because an explicit opts setting
         * overrides all earlier +/- modifiers
         */
        conf->opts = add->opts;
        conf->opts_add = add->opts_add;
        conf->opts_remove = add->opts_remove;
    }

    return conf;
}
