package TestProtocol::echo_filter;

use strict;
use warnings FATAL => 'all';

use Apache::Connection ();
use APR::Bucket ();
use APR::Brigade ();
use APR::Util ();

use APR::Const -compile => qw(SUCCESS EOF);
use Apache::Const -compile => qw(OK MODE_GETLINE);

sub handler {
    my Apache::Connection $c = shift;

    my $bb = APR::Brigade->new($c->pool, $c->bucket_alloc);

    for (;;) {
        my $rv = $c->input_filters->get_brigade($bb, Apache::MODE_GETLINE);
                if ($rv != APR::SUCCESS && $rv != APR::EOF) {
            my $error = APR::strerror($rv);
            warn __PACKAGE__ . ": get_brigade: $error\n";
            last;
        }

        last if $bb->empty;

        my $b = APR::Bucket::flush_create($c->bucket_alloc);
        $bb->insert_tail($b);
        $c->output_filters->pass_brigade($bb);
    }

    $bb->destroy;

    Apache::OK;
}

1;
