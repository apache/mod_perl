use Apache::RequestRec ();
use Apache::RequestIO ();

use Apache::Server ();
use Apache::Connection ();

use Apache::Const -compile => ':common';
use APR::Const -compile => ':common';

use APR::Table ();

sub ModPerl::Test::read_post {
    my $r = shift;

    $r->setup_client_block;

    return undef unless $r->should_client_block;

    my $len = $r->headers_in->get('content-length');

    my $buf;
    $r->get_client_block($buf, $len);

    return $buf;
}

1;
