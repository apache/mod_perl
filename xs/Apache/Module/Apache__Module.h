#define mpxs_Apache__Module_top_module(CLASS) \
(CLASS ? ap_top_module : ap_top_module)

static MP_INLINE int mpxs_Apache__Module_loaded(pTHX_ char *name)
{
    char nameptr[256];
    char *base;
    module *modp;

    /* Does the module name have a '.' in it ? */
    if ((base = ap_strchr(name, '.'))) {
        int len = base - name;

        memcpy(nameptr, name, len);
        memcpy(nameptr + len, ".c\0", 3);

        /* check if module is loaded */
        if (!(modp = ap_find_linked_module(nameptr))) {
            return 0;
        }

        if (*(base + 1) == 'c') {
            return 1;
        }

        /* if it ends in '.so', check if it was dynamically loaded */
        if ((strlen(base+1) == 2) &&
            (*(base + 1) == 's') && (*(base + 2) == 'o') &&
            modp->dynamic_load_handle)
        {
            return 1;
        }

        return 0;
    }
    else {
        return modperl_perl_module_loaded(aTHX_ name);
    }
}
