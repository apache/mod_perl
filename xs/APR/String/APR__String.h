static MP_INLINE
SV *mpxs_APR__String_format_size(pTHX_ apr_off_t  size)
{
    char buff[5];

    apr_strfsize(size, buff);

    return newSVpvn(buff, 4);    
}
