use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::RequestUtil ();

use Apache::Server ();
use Apache::Connection ();
use Apache::Log ();

use Apache::Const -compile => ':common';
use APR::Const -compile => ':common';

eval { require TestFilter::input_msg };

use APR::Table ();

my $ap_mods = scalar grep { /^Apache/ } keys %INC;
my $apr_mods = scalar grep { /^APR/ } keys %INC;

Apache::Log->info("$ap_mods Apache:: modules loaded");
Apache::Server->log->info("$apr_mods APR:: modules loaded");

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
