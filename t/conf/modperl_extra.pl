use Apache2 ();

use ModPerl::Util (); #for CORE::GLOBAL::exit

use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::RequestUtil ();

use Apache::Server ();
use Apache::ServerUtil ();
use Apache::Connection ();
use Apache::Log ();

use Apache::Const -compile => ':common';
use APR::Const -compile => ':common';

eval { require TestFilter::input_msg };

use APR::Table ();

unless ($ENV{MOD_PERL}) {
    die '$ENV{MOD_PERL} not set!';
}

#see t/response/TestModperl/env.pm
$ENV{MODPERL_EXTRA_PL} = __FILE__;

my $ap_mods = scalar grep { /^Apache/ } keys %INC;
my $apr_mods = scalar grep { /^APR/ } keys %INC;

Apache::Log->info("$ap_mods Apache:: modules loaded");
Apache::Server->log->info("$apr_mods APR:: modules loaded");

{
    my $server = Apache->server;
    my $vhosts = 0;
    for (my $s = $server->next; $s; $s = $s->next) {
        $vhosts++;
    }
    $server->log->info("base server + $vhosts vhosts ready to run tests");
}

sub ModPerl::Test::read_post {
    my $r = shift;

    $r->setup_client_block;

    return undef unless $r->should_client_block;

    my $len = $r->headers_in->get('content-length');

    my $buf;
    $r->get_client_block($buf, $len);

    return $buf;
}

END {
    warn "END in modperl_extra.pl, pid=$$\n";
}

1;
