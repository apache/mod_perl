#define mpxs_Apache__Directive_conftree(CLASS) \
(CLASS ? ap_conftree : ap_conftree)

typedef struct {
    AV *av;
    I32 ix;
    PerlInterpreter *perl;
} svav_param_t;

static void *svav_getstr(void *buf, size_t bufsiz, void *param)
{
    svav_param_t *svav_param = (svav_param_t *)param;
    dTHXa(svav_param->perl);
    AV *av = svav_param->av;
    SV *sv;
    STRLEN n_a;

    if (svav_param->ix > AvFILL(av)) {
        return NULL;
    }

    sv = AvARRAY(av)[svav_param->ix++];
    SvPV_force(sv, n_a);

    apr_cpystrn(buf, SvPVX(sv), bufsiz);

    return buf;
}

static MP_INLINE const char *mpxs_Apache__Directive_insert(pTHX_
                                                           SV *self,
                                                           server_rec *s,
                                                           apr_pool_t *p,
                                                           SV *svav)
{
    const char *errmsg;
    cmd_parms parms;
    svav_param_t svav_parms;
    ap_directive_t *conftree = NULL; /* XXX: self isa Apache::Directive */

    memset(&parms, '\0', sizeof(parms));

    parms.limited = -1;
    parms.pool = p;
    parms.server = s;
    parms.override = (RSRC_CONF | OR_ALL) & ~(OR_AUTHCFG | OR_LIMIT);
    apr_pool_create(&parms.temp_pool, p);

    if (!(SvROK(svav) && (SvTYPE(SvRV(svav)) == SVt_PVAV))) {
        return "not an array reference";
    }

    svav_parms.av = (AV*)SvRV(svav);
    svav_parms.ix = 0;
#ifdef USE_ITHREADS
    svav_parms.perl = aTHX;
#endif

    parms.config_file = ap_pcfg_open_custom(p, "mod_perl",
                                            &svav_parms, NULL,
                                            svav_getstr, NULL);

    errmsg = ap_build_config(&parms, p, parms.temp_pool, &conftree);

    if (!errmsg) {
        errmsg = ap_walk_config(conftree, &parms, s->lookup_defaults);
    }

    ap_cfg_closefile(parms.config_file);
    apr_pool_destroy(parms.temp_pool);

    return errmsg;
}

/* XXX: this is only useful for <Perl> at the moment */
SV *mpxs_Apache__Directive_to_string(pTHX_ ap_directive_t *self)
{
    ap_directive_t *d;
    SV *sv = newSVpv("", 0);

    for (d = self->first_child; d; d = d->next) {
        sv_catpv(sv, d->directive);
        sv_catpv(sv, " ");
        sv_catpv(sv, d->args);
        sv_catpv(sv, "\n");
    }

    return sv;
}
