#ifndef MODPERL_CGI_H
#define MODPERL_CGI_H

/**
 * split the HTTP headers from the body (if any) and feed them to
 * Apache. Populate the pointer to the remaining data in the buffer
 * (body if any or NULL)
 *
 * @param r       request_rec
 * @param buffer  a string with headers and potentially body
 *                (could be non-null terminated)
 * @param len     length of 'buffer' on entry
 *                length of 'body' on return
 * @param body    pointer to the body within the 'buffer' on return
 *                NULL if the buffer contained only headers
 *
 * @return status
 */
MP_INLINE int modperl_cgi_header_parse(request_rec *r, char *buffer,
                                       int *len, const char **body);

#endif /* MODPERL_CGI_H */
