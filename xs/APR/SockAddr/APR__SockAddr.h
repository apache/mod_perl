static MP_INLINE char *
mpxs_apr_sockaddr_ip_get(pTHX_ apr_sockaddr_t *sockaddr)
{
    char *addr = NULL;

    (void)apr_sockaddr_ip_get(&addr, sockaddr);

    return addr;
}

static MP_INLINE apr_port_t
mpxs_apr_sockaddr_port_get(pTHX_ apr_sockaddr_t *sockaddr)
{
    apr_port_t port = 0;

    (void)apr_sockaddr_port_get(&port, sockaddr);

    return port;
}
