/* Copyright 2001-2005 The Apache Software Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#define mpxs_Apache2__ServerUtil_restart_count modperl_restart_count

#define mpxs_Apache2__ServerRec_method_register(s, methname)     \
    ap_method_register(s->process->pconf, methname);

#define mpxs_Apache2__ServerRec_add_version_component(s, component)    \
    ap_add_version_component(s->process->pconf, component);

/* XXX: the mpxs_cleanup_t and mpxs_cleanup_run are almost dups with
 * code in APR__Pool.h (minus interpr member which is not used
 * here. They should be moved to modperl_common_util - the problem is
 * modperl_interp_t *, which can't live in modperl_common_* since it
 * creates a dependency on mod_perl. A possible solution is to use
 * void * for that slot and cast it to modperl_interp_t * when used
 */

typedef struct {
    SV *cv;
    SV *arg;
    apr_pool_t *p;
#ifdef USE_ITHREADS
    PerlInterpreter *perl;
#endif
} mpxs_cleanup2_t;

/**
 * callback wrapper for Perl cleanup subroutines
 * @param data   internal storage
 */
static apr_status_t mpxs_cleanup_run(void *data)
{
    int count;
    mpxs_cleanup2_t *cdata = (mpxs_cleanup2_t *)data;
#ifdef USE_ITHREADS
    dTHXa(cdata->perl);
#endif
    dSP;

    ENTER;SAVETMPS;
    PUSHMARK(SP);
    if (cdata->arg) {
        XPUSHs(cdata->arg);
    }
    PUTBACK;

    count = call_sv(cdata->cv, G_SCALAR|G_EVAL);

    SPAGAIN;

    if (count == 1) {
        (void)POPs; /* the return value is ignored */
    }

    PUTBACK;
    FREETMPS;LEAVE;

    SvREFCNT_dec(cdata->cv);
    if (cdata->arg) {
        SvREFCNT_dec(cdata->arg);
    }

    if (SvTRUE(ERRSV)) {
        Perl_croak(aTHX_ SvPV_nolen(ERRSV));
    }

    /* the return value is ignored by apr_pool_destroy anyway */
    return APR_SUCCESS;
}

/* this cleanups registered by this function are run only by the
 * parent interpreter */
static MP_INLINE
void mpxs_Apache2__ServerUtil_server_shutdown_cleanup_register(pTHX_ SV *cv,
                                                              SV *arg)
{
    mpxs_cleanup2_t *data;
    apr_pool_t *p;

    MP_CROAK_IF_POST_POST_CONFIG_PHASE("server_shutdown_cleanup_register");

    p = modperl_server_user_pool();
    /* must use modperl_server_user_pool here to make sure that it's run
     * before parent perl is destroyed */
    data = (mpxs_cleanup2_t *)apr_pcalloc(p, sizeof(*data));
    data->cv   = SvREFCNT_inc(cv);
    data->arg  = arg ? SvREFCNT_inc(arg) : Nullsv;
    data->p    = p;
#ifdef USE_ITHREADS
    data->perl = aTHX;
#endif /* USE_ITHREADS */

    apr_pool_cleanup_register(p, data, mpxs_cleanup_run,
                              apr_pool_cleanup_null);
}

static MP_INLINE
int mpxs_Apache2__ServerRec_push_handlers(pTHX_ server_rec *s,
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
int mpxs_Apache2__ServerRec_set_handlers(pTHX_ server_rec *s,
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
SV *mpxs_Apache2__ServerRec_get_handlers(pTHX_ server_rec *s,
                                     const char *name)
{
    MpAV **handp =
        modperl_handler_get_handlers(NULL, NULL, s,
                                     s->process->pconf, name,
                                     MP_HANDLER_ACTION_GET);

    return modperl_handler_perl_get_handlers(aTHX_ handp,
                                             s->process->pconf);
}

#define mpxs_Apache2__ServerRec_dir_config(s, key, sv_val) \
    modperl_dir_config(aTHX_ NULL, s, key, sv_val)

#define mpxs_Apache2_server(classname) modperl_global_get_server_rec()

static MP_INLINE
int mpxs_Apache2__ServerRec_is_perl_option_enabled(pTHX_ server_rec *s,
                                               const char *name)
{
    return modperl_config_is_perl_option_enabled(aTHX_ NULL, s, name);
}


static MP_INLINE
void mpxs_Apache2__ServerRec_add_config(pTHX_ server_rec *s, SV *lines)
{
    const char *errmsg = modperl_config_insert_server(aTHX_ s, lines);
    if (errmsg) {
        Perl_croak(aTHX_ "$s->add_config() has failed: %s", errmsg);
    }
}

static void mpxs_Apache2__ServerUtil_BOOT(pTHX)
{
    newCONSTSUB(PL_defstash, "Apache2::ServerUtil::server_root",
                newSVpv(ap_server_root, 0));

    newCONSTSUB(PL_defstash, "Apache2::ServerUtil::get_server_built",
                newSVpv(ap_get_server_built(), 0));

    newCONSTSUB(PL_defstash, "Apache2::ServerUtil::get_server_version",
                newSVpv(ap_get_server_version(), 0));
}
