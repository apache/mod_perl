static MP_INLINE char *
mpxs_apr_sockaddr_ip_get(pTHX_ apr_sockaddr_t *sockaddr)
{
    char *addr = NULL;

    (void)apr_sockaddr_ip_get(&addr, sockaddr);

    return addr;
}
