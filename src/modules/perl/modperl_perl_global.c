#include "mod_perl.h"

static void modperl_perl_global_init(pTHX_ modperl_perl_globals_t *globals)
{
    globals->env.gv    = PL_envgv;
    globals->inc.gv    = PL_incgv;
    globals->defout.gv = PL_defoutgv;
    globals->rs.sv     = &PL_rs;
    globals->end.av    = &PL_endav;
    globals->end.key   = MP_MODGLOBAL_END;
}

/* XXX: PL_modglobal thingers might be useful elsewhere */

#define MP_MODGLOBAL_ENT(key) \
{key, "ModPerl::" key, (sizeof("ModPerl::")-1)+(sizeof(key)-1)}

static modperl_modglobal_key_t MP_modglobal_keys[] = {
    MP_MODGLOBAL_ENT("END"),
    { NULL },
};

modperl_modglobal_key_t *modperl_modglobal_lookup(pTHX_ const char *name)
{
    int i;

    for (i=0; MP_modglobal_keys[i].name; i++) {
        if (strEQ(MP_modglobal_keys[i].name, name)) {
            return &MP_modglobal_keys[i];
        }
    }

    return NULL;
}

static AV *modperl_perl_global_avcv_fetch(pTHX_ modperl_modglobal_key_t *gkey,
                                          const char *package, I32 packlen)
{
    SV **svp = hv_fetch(PL_modglobal, gkey->val, gkey->len, FALSE);
    HV *hv;

    if (!(svp && (hv = (HV*)*svp))) {
        return Nullav;
    }

    if (!(svp = hv_fetch(hv, package, packlen, FALSE))) {
        return Nullav;
    }

    return (AV*)*svp;
}

void modperl_perl_global_avcv_call(pTHX_ modperl_modglobal_key_t *gkey,
                                   const char *package, I32 packlen)
{
    AV *av = modperl_perl_global_avcv_fetch(aTHX_ gkey, package, packlen);

    if (!av) {
        return;
    }

    modperl_perl_call_list(aTHX_ av, gkey->name);
}

void modperl_perl_global_avcv_clear(pTHX_ modperl_modglobal_key_t *gkey,
                                    const char *package, I32 packlen)
{
    AV *av = modperl_perl_global_avcv_fetch(aTHX_ gkey, package, packlen);

    if (!av) {
        return;
    }

    av_clear(av);
}

static int modperl_perl_global_avcv_set(pTHX_ SV *sv, MAGIC *mg)
{
    HV *hv;
    AV *mav, *av = (AV*)sv;
    const char *package = HvNAME(PL_curstash);
    I32 packlen = strlen(package);
    modperl_modglobal_key_t *gkey =
        (modperl_modglobal_key_t *)mg->mg_ptr;

    hv = (HV*)*hv_fetch(PL_modglobal, gkey->val, gkey->len, TRUE);
    (void)SvUPGRADE((SV*)hv, SVt_PVHV);

    mav = (AV*)*hv_fetch(hv, package, packlen, TRUE);
    (void)SvUPGRADE((SV*)mav, SVt_PVAV);

    /* $cv = pop @av */
    sv = AvARRAY(av)[AvFILLp(av)];
    AvARRAY(av)[AvFILLp(av)--] = &PL_sv_undef;

    /* push @{ $PL_modglobal{$key}{$package} }, $cv */
    av_store(mav, AvFILLp(av)+1, sv);

    return 1;
}

static MGVTBL modperl_vtbl_global_avcv_t = {
    0,
    MEMBER_TO_FPTR(modperl_perl_global_avcv_set),
    0, 0, 0,
};

/* XXX: Apache::RegistryLoader type things need access to this
 * for compiling scripts at startup
 */
static void modperl_perl_global_avcv_tie(pTHX_ modperl_modglobal_key_e key,
                                         AV *av)
{
    if (!SvMAGIC((SV*)av)) {
        MAGIC *mg;
        Newz(702, mg, 1, MAGIC);
        mg->mg_virtual = &modperl_vtbl_global_avcv_t;
        mg->mg_ptr = (char *)&MP_modglobal_keys[key];
        mg->mg_len = -1; /* prevent free() of mg->mg_ptr */
        SvMAGIC((SV*)av) = mg;
    }

    SvSMAGICAL_on((SV*)av);
}

static void modperl_perl_global_avcv_untie(pTHX_ AV *av)
{
    SvSMAGICAL_off((SV*)av);
}

static void
modperl_perl_global_avcv_save(pTHX_ modperl_perl_global_avcv_t *avcv)
{
    avcv->origav = *avcv->av;
    *avcv->av = newAV(); /* XXX: only need 1 of these AVs per-interpreter */
    modperl_perl_global_avcv_tie(aTHX_ avcv->key, *avcv->av);
}

static void
modperl_perl_global_avcv_restore(pTHX_ modperl_perl_global_avcv_t *avcv)
{
    modperl_perl_global_avcv_untie(aTHX_ *avcv->av);
    SvREFCNT_dec(*avcv->av); /* XXX: see XXX above */
    *avcv->av = avcv->origav;
}

static void
modperl_perl_global_gvhv_save(pTHX_ modperl_perl_global_gvhv_t *gvhv)
{
    U32 mg_flags;
    HV *hv = GvHV(gvhv->gv);

    /*
     * there should only be a small number of entries in %ENV
     * at this point: modperl_env.c:modperl_env_const_vars[],
     * PerlPassEnv and top-level PerlSetEnv
     * XXX: still; could have have something faster than newHVhv()
     * especially if we add another GVHV to the globals table that 
     * might have more entries
     */

    /* makes newHVhv() faster in bleedperl */
    MP_magical_untie(hv, mg_flags);

    gvhv->tmphv = newHVhv(hv);
    TAINT_NOT;

    /* reapply magic flags */
    MP_magical_tie(hv, mg_flags);
    MP_magical_tie(gvhv->tmphv, mg_flags);

    gvhv->orighv = hv;
    GvHV(gvhv->gv) = gvhv->tmphv;
}

static void
modperl_perl_global_gvhv_restore(pTHX_ modperl_perl_global_gvhv_t *gvhv)
{
    U32 mg_flags;

    GvHV(gvhv->gv) = gvhv->orighv;

    /* loose magic for hv_clear()
     * e.g. for %ENV don't want to clear environ array
     */
    MP_magical_untie(gvhv->tmphv, mg_flags);
    SvREFCNT_dec(gvhv->tmphv);
}

static void
modperl_perl_global_gvav_save(pTHX_ modperl_perl_global_gvav_t *gvav)
{
    gvav->origav = GvAV(gvav->gv);
    gvav->tmpav = newAV();
    modperl_perl_av_push_elts_ref(aTHX_ gvav->tmpav, gvav->origav);
    GvAV(gvav->gv) = gvav->tmpav;
}

static void
modperl_perl_global_gvav_restore(pTHX_ modperl_perl_global_gvav_t *gvav)
{
    GvAV(gvav->gv) = gvav->origav;
    SvREFCNT_dec(gvav->tmpav);
}

static void
modperl_perl_global_gvio_save(pTHX_ modperl_perl_global_gvio_t *gvio)
{
    gvio->flags = IoFLAGS(GvIOp(gvio->gv));
}

static void
modperl_perl_global_gvio_restore(pTHX_ modperl_perl_global_gvio_t *gvio)
{
    IoFLAGS(GvIOp(gvio->gv)) = gvio->flags;
}

static void
modperl_perl_global_svpv_save(pTHX_ modperl_perl_global_svpv_t *svpv)
{
    svpv->cur = SvCUR(*svpv->sv);
    strncpy(svpv->pv, SvPVX(*svpv->sv), sizeof(svpv->pv));
}

static void
modperl_perl_global_svpv_restore(pTHX_ modperl_perl_global_svpv_t *svpv)
{
    sv_setpvn(*svpv->sv, svpv->pv, svpv->cur);
}

typedef enum {
    MP_GLOBAL_AVCV,
    MP_GLOBAL_GVHV,
    MP_GLOBAL_GVAV,
    MP_GLOBAL_GVIO,
    MP_GLOBAL_SVPV,
} modperl_perl_global_types_e;

typedef struct {
    char *name;
    int offset;
    modperl_perl_global_types_e type;
} modperl_perl_global_entry_t;

#define MP_GLOBAL_OFFSET(m) \
    STRUCT_OFFSET(modperl_perl_globals_t, m)

static modperl_perl_global_entry_t MP_perl_global_entries[] = {
    {"END",    MP_GLOBAL_OFFSET(end),    MP_GLOBAL_AVCV}, /* END */
    {"ENV",    MP_GLOBAL_OFFSET(env),    MP_GLOBAL_GVHV}, /* %ENV */
    {"INC",    MP_GLOBAL_OFFSET(inc),    MP_GLOBAL_GVAV}, /* @INC */
    {"STDOUT", MP_GLOBAL_OFFSET(defout), MP_GLOBAL_GVIO}, /* $| */
    {"/",      MP_GLOBAL_OFFSET(rs),     MP_GLOBAL_SVPV}, /* $/ */
    {NULL}
};

#define MP_PERL_GLOBAL_SAVE(type, ptr) \
    modperl_perl_global_##type##_save( \
        aTHX_ (modperl_perl_global_##type##_t *)&(*ptr))

#define MP_PERL_GLOBAL_RESTORE(type, ptr) \
    modperl_perl_global_##type##_restore( \
        aTHX_ (modperl_perl_global_##type##_t *)&(*ptr))

#define MP_dGLOBAL_PTR(globals, entries) \
    apr_uint64_t **ptr = (apr_uint64_t **) \
        ((char *)globals + (int)(long)entries->offset)

static void modperl_perl_global_save(pTHX_ modperl_perl_globals_t *globals,
                                     modperl_perl_global_entry_t *entries)
{
    modperl_perl_global_init(aTHX_ globals);

    while (entries->name) {
        MP_dGLOBAL_PTR(globals, entries);

        switch (entries->type) {
          case MP_GLOBAL_AVCV:
            MP_PERL_GLOBAL_SAVE(avcv, ptr);
            break;
          case MP_GLOBAL_GVHV:
            MP_PERL_GLOBAL_SAVE(gvhv, ptr);
            break;
          case MP_GLOBAL_GVAV:
            MP_PERL_GLOBAL_SAVE(gvav, ptr);
            break;
          case MP_GLOBAL_GVIO:
            MP_PERL_GLOBAL_SAVE(gvio, ptr);
            break;
          case MP_GLOBAL_SVPV:
            MP_PERL_GLOBAL_SAVE(svpv, ptr);
            break;
        }

        entries++;
    }
}

static void modperl_perl_global_restore(pTHX_ modperl_perl_globals_t *globals,
                                        modperl_perl_global_entry_t *entries)
{
    while (entries->name) {
        MP_dGLOBAL_PTR(globals, entries);

        switch (entries->type) {
          case MP_GLOBAL_AVCV:
            MP_PERL_GLOBAL_RESTORE(avcv, ptr);
            break;
          case MP_GLOBAL_GVHV:
            MP_PERL_GLOBAL_RESTORE(gvhv, ptr);
            break;
          case MP_GLOBAL_GVAV:
            MP_PERL_GLOBAL_RESTORE(gvav, ptr);
            break;
          case MP_GLOBAL_GVIO:
            MP_PERL_GLOBAL_RESTORE(gvio, ptr);
            break;
          case MP_GLOBAL_SVPV:
            MP_PERL_GLOBAL_RESTORE(svpv, ptr);
            break;
        }

        entries++;
    }
}

void modperl_perl_global_request_save(pTHX_ request_rec *r)
{
    MP_dRCFG;
    modperl_perl_global_save(aTHX_ &rcfg->perl_globals,
                             MP_perl_global_entries);
}

void modperl_perl_global_request_restore(pTHX_ request_rec *r)
{
    MP_dRCFG;
    modperl_perl_global_restore(aTHX_ &rcfg->perl_globals,
                                MP_perl_global_entries);

}
