package TestHooks::default_port;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use APR::Table ();
use Apache::RequestRec ();
use Apache::RequestIO ();

use Apache::Const -compile => qw(OK DECLINED);

sub handler {
    my $r = shift;

    my $port = $r->args || Apache::OK;

    return int $port;
}

sub response {
    my $r = shift;

    $r->content_type('text/plain');

    $r->print($r->get_server_port);

    return Apache::OK;
}

1;
__DATA__
# create a new virtual host so we can put the
# PerlDefaultPortHandler on a per-server level
# and it doesn't muck with existing tests
<NoAutoConfig>
<VirtualHost TestHooks::default_port>
    # this ServerName overrides the configured ServerName
    # hope that doesn't change someday...
    ServerName foo.example.com
    UseCanonicalName Off
    PerlModule TestHooks::default_port
    PerlDefaultPortHandler TestHooks::default_port
    PerlResponseHandler TestHooks::default_port::response
    SetHandler modperl
</VirtualHost>

# make sure that default mod_perl behavior
# (DECLINED) doesn't mess up everyone else
<VirtualHost TestHooks::default_port2>
    UseCanonicalName Off
    PerlResponseHandler TestHooks::default_port::response
    SetHandler modperl
</VirtualHost>

# make sure that default mod_perl behavior
# (DECLINED) doesn't mess up everyone else (again)
<VirtualHost TestHooks::default_port3>
    UseCanonicalName On
    PerlResponseHandler TestHooks::default_port::response
    SetHandler modperl
</VirtualHost>
</NoAutoConfig>
