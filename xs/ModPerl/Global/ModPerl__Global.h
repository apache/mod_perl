typedef void (*mpxs_special_list_do_t)(pTHX_ modperl_modglobal_key_t *,
                                       const char *, I32);

static int mpxs_special_list_do(pTHX_ const char *name,
                                SV *package,
                                mpxs_special_list_do_t func)
{
    STRLEN packlen;
    char *packname;
    modperl_modglobal_key_t *gkey = modperl_modglobal_lookup(aTHX_ name);

    if (!gkey) {
        return FALSE;
    }

    packname = SvPV(package, packlen);

    func(aTHX_ gkey, packname, packlen);

    return TRUE;
}

static
MP_INLINE int mpxs_ModPerl__Global_special_list_call(pTHX_ const char *name,
                                                     SV *package)
{
    return mpxs_special_list_do(aTHX_ name, package,
                                modperl_perl_global_avcv_call);
}

static
MP_INLINE int mpxs_ModPerl__Global_special_list_clear(pTHX_ const char *name,
                                                      SV *package)
{
    return mpxs_special_list_do(aTHX_ name, package,
                                modperl_perl_global_avcv_clear);
}
