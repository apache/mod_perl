package TestFilter::both_str_req_proxy;

# very similar to TestFilter::both_str_req_add, but the request is
# proxified. we filter the POSTed body before it goes via the proxy and
# we filter the response after it returned from the proxy

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::Filter ();

use Apache::TestTrace;

use Apache::Const -compile => qw(OK M_POST);

sub in_filter {
    my $filter = shift;

    debug "input filter";

    while ($filter->read(my $buffer, 1024)) {
        $filter->print(lc $buffer);
    }

    Apache::OK;
}

sub out_filter {
    my $filter = shift;

    debug "output filter";

    while ($filter->read(my $buffer, 1024)) {
        $buffer =~ s/\s+//g;
        $filter->print($buffer);
    }

    Apache::OK;
}

sub handler {
    my $r = shift;

    debug "response handler";

    $r->content_type('text/plain');

    if ($r->method_number == Apache::M_POST) {
        $r->print(ModPerl::Test::read_post($r));
    }

    return Apache::OK;
}

1;
__DATA__
<NoAutoConfig>
    <IfModule mod_proxy.c>
        <IfModule mod_access.c>
            <Proxy http://@servername@:@port@/*>
                Order Deny,Allow
                Deny from all
                Allow from @servername@
            </Proxy>
            ProxyRequests Off
            RewriteEngine On

            ProxyPass    /TestFilter__both_str_req_proxy/ \
            http://@servername@:@port@/TestFilter__both_str_req_proxy_content/
            ProxyPassReverse /TestFilter__both_str_req_proxy/ \
            http://@servername@:@port@/TestFilter__both_str_req_proxy_content/
    </IfModule>
    </IfModule>

    PerlModule TestFilter::both_str_req_proxy
    <Location /TestFilter__both_str_req_proxy>
        PerlInputFilterHandler  TestFilter::both_str_req_proxy::in_filter
        PerlOutputFilterHandler TestFilter::both_str_req_proxy::out_filter
    </Location>
    <Location /TestFilter__both_str_req_proxy_content>
        SetHandler modperl
        PerlResponseHandler     TestFilter::both_str_req_proxy
    </Location>
</NoAutoConfig>




