#define mpxs_apr_uuid_alloc() \
(apr_uuid_t *)safemalloc(sizeof(apr_uuid_t))

static MP_INLINE apr_uuid_t *mpxs_apr_uuid_get(pTHX_ SV *CLASS)
{
    apr_uuid_t *uuid = mpxs_apr_uuid_alloc();
    apr_uuid_get(uuid);
    return uuid;
}

static MP_INLINE void mp_apr_uuid_format(pTHX_ SV *sv, SV *obj)
{
    apr_uuid_t *uuid = mp_xs_sv2_uuid(obj);
    mpxs_sv_grow(sv, APR_UUID_FORMATTED_LENGTH);
    apr_uuid_format(SvPVX(sv), uuid);
    mpxs_sv_cur_set(sv, APR_UUID_FORMATTED_LENGTH);
}

static MP_INLINE apr_uuid_t *mpxs_apr_uuid_parse(pTHX_ SV *CLASS, char *buf)
{
    apr_uuid_t *uuid = mpxs_apr_uuid_alloc();
    apr_uuid_parse(uuid, buf);
    return uuid;
}

static XS(MPXS_apr_uuid_format)
{
    dXSARGS;

    mpxs_usage_items_1("uuid");

    mpxs_set_targ(mp_apr_uuid_format, ST(0));
}

#define apr_uuid_DESTROY(uuid) safefree(uuid)
