static MP_INLINE
int mpxs_Apache__Server_push_handlers(server_rec *s,
                                      const char *name,
                                      SV *sv)
{
    dTHX; /*XXX*/
    return modperl_handler_perl_add_handlers(aTHX_
                                             NULL, NULL, s,
                                             s->process->pconf,
                                             name, sv,
                                             MP_HANDLER_ACTION_PUSH);

}

static MP_INLINE
int mpxs_Apache__Server_set_handlers(server_rec *s,
                                     const char *name,
                                     SV *sv)
{
    dTHX; /*XXX*/
    return modperl_handler_perl_add_handlers(aTHX_
                                             NULL, NULL, s,
                                             s->process->pconf,
                                             name, sv,
                                             MP_HANDLER_ACTION_SET);
}

static MP_INLINE
SV *mpxs_Apache__Server_get_handlers(server_rec *s,
                                     const char *name)
{
    dTHX; /*XXX*/
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
