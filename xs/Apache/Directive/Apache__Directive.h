#define mpxs_Apache__Directive_conftree(CLASS) \
(CLASS ? ap_conftree : ap_conftree)

/* XXX: this is only useful for <Perl> at the moment */
static MP_INLINE SV *mpxs_Apache__Directive_as_string(pTHX_
                                                      ap_directive_t *self)
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
