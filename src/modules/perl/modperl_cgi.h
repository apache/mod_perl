#ifndef MODPERL_CGI_H
#define MODPERL_CGI_H

MP_INLINE int modperl_cgi_header_parse(request_rec *r, char *buffer,
                                       const char **bodytext);

#endif /* MODPERL_CGI_H */
