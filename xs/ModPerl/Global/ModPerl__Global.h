typedef void (*mpxs_special_list_do_t)(pTHX_ modperl_modglobal_key_t *,
                                       const char *, I32);

static int mpxs_special_list_do(pTHX_ const char *name,
                                SV *package,
                                mpxs_special_list_do_t func)
{
    STRLEN packlen;
    modperl_modglobal_key_t *gkey = modperl_modglobal_lookup(aTHX_ name);

    if (!gkey) {
        return FALSE;
    }

    SvPV_force(package, packlen);

    func(aTHX_ gkey, SvPVX(package), packlen);

    return TRUE;
}

static
MP_INLINE int mpxs_ModPerl__Global_special_list_call(const char *name,
                                                     SV *package)
{
    dTHX; /* XXX */
    return mpxs_special_list_do(aTHX_ name, package,
                                modperl_perl_global_avcv_call);
}

static
MP_INLINE int mpxs_ModPerl__Global_special_list_clear(const char *name,
                                                      SV *package)
{
    dTHX; /* XXX */
    return mpxs_special_list_do(aTHX_ name, package,
                                modperl_perl_global_avcv_clear);
}
