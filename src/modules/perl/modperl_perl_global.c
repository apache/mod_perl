#include "mod_perl.h"

static void modperl_perl_global_init(pTHX_ modperl_perl_globals_t *globals)
{
    globals->env.gv    = PL_envgv;
    globals->inc.gv    = PL_incgv;
    globals->defout.gv = PL_defoutgv;
    globals->rs.sv     = &PL_rs;
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

static modperl_perl_global_entry_t modperl_perl_global_entries[] = {
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

#define MP_dGLOBAL_PTR(globals, i) \
    apr_uint64_t **ptr = (apr_uint64_t **) \
        ((char *)globals + (int)(long)modperl_perl_global_entries[i].offset)

static void modperl_perl_global_save(pTHX_ modperl_perl_globals_t *globals)
{
    int i;

    modperl_perl_global_init(aTHX_ globals);

    for (i=0; modperl_perl_global_entries[i].name; i++) {
        MP_dGLOBAL_PTR(globals, i);

        switch (modperl_perl_global_entries[i].type) {
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
        };
    }
}

static void modperl_perl_global_restore(pTHX_ modperl_perl_globals_t *globals)
{
    int i;

    for (i=0; modperl_perl_global_entries[i].name; i++) {
        MP_dGLOBAL_PTR(globals, i);

        switch (modperl_perl_global_entries[i].type) {
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
    }
}

void modperl_perl_global_request_save(pTHX_ request_rec *r)
{
    MP_dRCFG;
    modperl_perl_global_save(aTHX_ &rcfg->perl_globals);
}

void modperl_perl_global_request_restore(pTHX_ request_rec *r)
{
    MP_dRCFG;
    modperl_perl_global_restore(aTHX_ &rcfg->perl_globals);
}
