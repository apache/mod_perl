#ifndef MODPERL_APACHE_XS_H
#define MODPERL_APACHE_XS_H

MP_INLINE apr_size_t modperl_apache_xs_write(pTHX_ I32 items,
                                             SV **MARK, SV **SP);

MP_INLINE apr_size_t modperl_filter_xs_write(pTHX_ I32 items,
                                             SV **MARK, SV **SP);

MP_INLINE apr_size_t modperl_filter_xs_read(pTHX_ I32 items,
                                            SV **MARK, SV **SP);

#endif /* MODPERL_APACHE_XS_H */
