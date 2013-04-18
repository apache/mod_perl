/* Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "mod_perl.h"

/* XXX: PL_modglobal thingers might be useful elsewhere */

#define MP_MODGLOBAL_ENT(key)                                           \
    {key, "ModPerl::" key, MP_SSTRLEN("ModPerl::") + MP_SSTRLEN(key), 0}

static modperl_modglobal_key_t MP_modglobal_keys[] = {
    MP_MODGLOBAL_ENT("END"),
    MP_MODGLOBAL_ENT("ANONSUB"),
    { NULL },
};

void modperl_modglobal_hash_keys(pTHX)
{
    modperl_modglobal_key_t *gkey = MP_modglobal_keys;

    while (gkey->name) {
        PERL_HASH(gkey->hash, gkey->val, gkey->len);
        gkey++;
    }
}

modperl_modglobal_key_t *modperl_modglobal_lookup(pTHX_ const char *name)
{
    modperl_modglobal_key_t *gkey = MP_modglobal_keys;

    while (gkey->name) {
        if (strEQ(gkey->name, name)) {
            return gkey;
        }
        gkey++;
    }

    return NULL;
}

static void modperl_perl_global_init(pTHX_ modperl_perl_globals_t *globals)
{
    globals->env.gv    = PL_envgv;
    globals->inc.gv    = PL_incgv;
    globals->defout.gv = PL_defoutgv;
    globals->rs.sv     = &PL_rs;
    globals->end.av    = &PL_endav;
    globals->end.key   = MP_MODGLOBAL_END;
}

/*
 * if (exists $PL_modglobal{$key}{$package}) {
 *      return $PL_modglobal{$key}{$package};
 * }
 * elsif ($autovivify) {
 *     return $PL_modglobal{$key}{$package} = [];
 * }
 * else {
 *     return (AV *)NULL; # a null pointer in C of course :)
 * }
 */
static AV *modperl_perl_global_avcv_fetch(pTHX_ modperl_modglobal_key_t *gkey,
                                          const char *package, I32 packlen,
                                          I32 autovivify)
{
    HE *he = MP_MODGLOBAL_FETCH(gkey);
    HV *hv;

    if (!(he && (hv = (HV*)HeVAL(he)))) {
        if (autovivify) {
            hv = MP_MODGLOBAL_STORE_HV(gkey);
        }
        else {
            return (AV *)NULL;
        }
    }

    if ((he = hv_fetch_he(hv, (char *)package, packlen, 0))) {
        return (AV*)HeVAL(he);
    }
    else {
        if (autovivify) {
            return (AV*)*hv_store(hv, package, packlen, (SV*)newAV(), 0);
        }
        else {
            return (AV *)NULL;
        }
    }
}

/* autovivify $PL_modglobal{$key}{$package} if it doesn't exist yet,
 * so that in modperl_perl_global_avcv_set we will know whether to
 * store blocks in it or keep them in the original list.
 *
 * For example in the case of END blocks, if
 * $PL_modglobal{END}{$package} exists, modperl_perl_global_avcv_set
 * will push newly encountered END blocks to it, otherwise it'll keep
 * them in PL_endav.
 */
void modperl_perl_global_avcv_register(pTHX_ modperl_modglobal_key_t *gkey,
                                       const char *package, I32 packlen)
{
    AV *av = modperl_perl_global_avcv_fetch(aTHX_ gkey,
                                            package, packlen, TRUE);

    MP_TRACE_g(MP_FUNC, "register PL_modglobal %s::%s (has %d entries)",
               package, (char*)gkey->name, av ? 1+av_len(av) : 0);
}

/* if (exists $PL_modglobal{$key}{$package}) {
 *     for my $cv (@{ $PL_modglobal{$key}{$package} }) {
 *         $cv->();
 *     }
 * }
 */
void modperl_perl_global_avcv_call(pTHX_ modperl_modglobal_key_t *gkey,
                                   const char *package, I32 packlen)
{
    AV *av = modperl_perl_global_avcv_fetch(aTHX_ gkey, package, packlen,
                                            FALSE);

    MP_TRACE_g(MP_FUNC, "run PL_modglobal %s::%s (has %d entries)",
               package, (char*)gkey->name, av ? 1+av_len(av) : 0);

    if (av) {
        modperl_perl_call_list(aTHX_ av, gkey->name);
    }
}


/* if (exists $PL_modglobal{$key}{$package}) {
 *     @{ $PL_modglobal{$key}{$package} } = ();
 * }
 */
void modperl_perl_global_avcv_clear(pTHX_ modperl_modglobal_key_t *gkey,
                                    const char *package, I32 packlen)
{
    AV *av = modperl_perl_global_avcv_fetch(aTHX_ gkey,
                                            package, packlen, FALSE);

    MP_TRACE_g(MP_FUNC, "clear PL_modglobal %s::%s (has %d entries)",
               package, (char*)gkey->name, av ? 1+av_len(av) : 0);

    if (av) {
        av_clear(av);
    }
}

static int modperl_perl_global_avcv_set(pTHX_ SV *sv, MAGIC *mg)
{
    AV *mav, *av = (AV*)sv;
    const char *package = HvNAME(PL_curstash);
    I32 packlen = strlen(package);
    modperl_modglobal_key_t *gkey =
        (modperl_modglobal_key_t *)mg->mg_ptr;

    /* the argument sv, is the original list perl was operating on.
     * (e.g. PL_endav). So now if we find that we have package/cv name
     * (e.g. Foo/END) registered for set-aside, we remove the cv that
     * was just unshifted in and push it into
     * $PL_modglobal{$key}{$package}. Otherwise we do nothing, which
     * keeps the unshifted cv (e.g. END block) in its original av
     * (e.g. PL_endav)
     */

    mav = modperl_perl_global_avcv_fetch(aTHX_ gkey, package, packlen, FALSE);

    if (!mav) {
        MP_TRACE_g(MP_FUNC, "%s::%s is not going to PL_modglobal",
                   package, (char*)gkey->name);
        /* keep it in the tied list (e.g. PL_endav) */
        return 1;
    }

    MP_TRACE_g(MP_FUNC, "%s::%s is going into PL_modglobal",
               package, (char*)gkey->name);

    sv = av_shift(av);

    /* push @{ $PL_modglobal{$key}{$package} }, $cv */
    av_store(mav, AvFILLp(mav)+1, sv);

    /* print scalar @{ $PL_modglobal{$key}{$package} } */
    MP_TRACE_g(MP_FUNC, "%s::%s av now has %d entries",
               package, (char*)gkey->name, 1+av_len(mav));

    return 1;
}

static MGVTBL modperl_vtbl_global_avcv_t = {
    0,
    modperl_perl_global_avcv_set,
    0, 0, 0,
};

static void modperl_perl_global_avcv_tie(pTHX_ modperl_modglobal_key_e key,
                                         AV *av)
{
    if (!SvMAGIC((SV*)av)) {
        MAGIC *mg;
        Newxz(mg, 1, MAGIC);
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
    if (!*avcv->av) {
        *avcv->av = newAV();
    }

    modperl_perl_global_avcv_tie(aTHX_ avcv->key, *avcv->av);
}

static void
modperl_perl_global_avcv_restore(pTHX_ modperl_perl_global_avcv_t *avcv)
{
    modperl_perl_global_avcv_untie(aTHX_ *avcv->av);
}

/*
 * newHVhv is not good enough since it does not copy magic.
 * XXX: 5.8.0+ newHVhv has some code thats faster than hv_iternext
 */
static HV *copyENV(pTHX_ HV *ohv)
{
    HE *entry, *hv_eiter;
    I32 hv_riter;
    register HV *hv;
    STRLEN hv_max = HvMAX(ohv);
    STRLEN hv_fill = HvFILL(ohv);

    hv = newHV();
    while (hv_max && hv_max + 1 >= hv_fill * 2) {
        hv_max = hv_max / 2;    /* Is always 2^n-1 */
    }

    HvMAX(hv) = hv_max;

    if (!hv_fill) {
        return hv;
    }

    hv_riter = HvRITER(ohv);    /* current root of iterator */
    hv_eiter = HvEITER(ohv);    /* current entry of iterator */

    hv_iterinit(ohv);
    while ((entry = hv_iternext(ohv))) {
        SV *sv = newSVsv(HeVAL(entry));
        modperl_envelem_tie(sv, HeKEY(entry), HeKLEN(entry));
        (void)hv_store(hv, HeKEY(entry), HeKLEN(entry),
                       sv, HeHASH(entry));
    }

    HvRITER(ohv) = hv_riter;
    HvEITER(ohv) = hv_eiter;

    hv_magic(hv, (GV *)NULL, 'E');

    TAINT_NOT;

    return hv;
}

static void
modperl_perl_global_gvhv_save(pTHX_ modperl_perl_global_gvhv_t *gvhv)
{
    HV *hv = GvHV(gvhv->gv);
#if 0
    U32 mg_flags;
    MAGIC *mg = SvMAGIC(hv);

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

    if (mg && mg->mg_type && !SvMAGIC(gvhv->tmphv)) {
        /* propagate SvMAGIC(hv) to SvMAGIC(gvhv->tmphv) */
        /* XXX: maybe newHVhv should do this? */
        hv_magic(gvhv->tmphv, (GV *)NULL, mg->mg_type);
    }
#else
    gvhv->tmphv = copyENV(aTHX_ hv);
#endif

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

    /* avoiding -Wall warning */
    mg_flags = mg_flags;
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
    MP_GLOBAL_SVPV
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
