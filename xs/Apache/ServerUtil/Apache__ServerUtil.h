static MP_INLINE
int mpxs_Apache__Server_push_handlers(pTHX_ server_rec *s,
                                      const char *name,
                                      SV *sv)
{
    return modperl_handler_perl_add_handlers(aTHX_
                                             NULL, NULL, s,
                                             s->process->pconf,
                                             name, sv,
                                             MP_HANDLER_ACTION_PUSH);

}

static MP_INLINE
int mpxs_Apache__Server_set_handlers(pTHX_ server_rec *s,
                                     const char *name,
                                     SV *sv)
{
    return modperl_handler_perl_add_handlers(aTHX_
                                             NULL, NULL, s,
                                             s->process->pconf,
                                             name, sv,
                                             MP_HANDLER_ACTION_SET);
}

static MP_INLINE
SV *mpxs_Apache__Server_get_handlers(pTHX_ server_rec *s,
                                     const char *name)
{
    MpAV **handp =
        modperl_handler_get_handlers(NULL, NULL, s,
                                     s->process->pconf, name,
                                     MP_HANDLER_ACTION_GET);

    return modperl_handler_perl_get_handlers(aTHX_ handp,
                                             s->process->pconf);
}

#define mpxs_Apache__Server_dir_config(s, key, sv_val) \
    modperl_dir_config(aTHX_ NULL, s, key, sv_val)

#define mpxs_Apache_server(classname) \
modperl_global_get_server_rec()

#define mpxs_Apache__Server_server_root_relative(sv, fname) \
    modperl_server_root_relative(aTHX_ sv, fname);

#define mpxs_Apache_server_root_relative(sv, fname) \
    modperl_server_root_relative(aTHX_ sv, fname)

static MP_INLINE
int mpxs_Apache__Server_is_perl_option_enabled(pTHX_ server_rec *s,
                                               const char *name)
{
    return modperl_config_is_perl_option_enabled(aTHX_ NULL, s, name);
}

static void mpxs_Apache__ServerUtil_BOOT(pTHX)
{
    newCONSTSUB(PL_defstash, "Apache::server_root",
                newSVpv(ap_server_root, 0));

    newCONSTSUB(PL_defstash, "Apache::Server::get_server_built",
                newSVpv(ap_get_server_built(), 0));
}
