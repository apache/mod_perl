package TestProtocol::echo_filter;

use strict;
use Apache::Connection ();
use APR::Bucket ();
use APR::Brigade ();
use APR::Const -compile => qw(SUCCESS);
use Apache::Const -compile => qw(MODE_BLOCKING);
use APR::Lib ();

sub handler {
    my Apache::Connection $c = shift;

    my $bb = APR::Brigade->new($c->pool);

    for (;;) {
        my $rv = $c->input_filters->get_brigade($bb,
                                                Apache::MODE_BLOCKING);

        if ($rv != APR::SUCCESS or $bb->empty) {
            my $error = APR::strerror($rv);
            warn "get_brigade: $error\n";
            $bb->destroy;
            last;
        }

        my $b = APR::Bucket::flush_create();
        $bb->insert_tail($b);
        $c->output_filters->pass_brigade($bb);
    }

    return Apache::OK;
}

1;
