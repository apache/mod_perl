package TestProtocol::echo_bbs;

# this test is similar to TestProtocol::echo_filter, but performs the
# manipulations on the buckets inside the connection handler, rather
# then using filter

use strict;
use warnings FATAL => 'all';

use Apache::Connection ();
use APR::Socket ();
use APR::Bucket ();
use APR::Brigade ();
use APR::Error ();

use Apache::Const -compile => qw(OK MODE_GETLINE);
use APR::Const    -compile => qw(SUCCESS EOF SO_NONBLOCK);

sub handler {
    my $c = shift;

    # starting from Apache 2.0.49 several platforms require you to set
    # the socket to a blocking IO mode
    $c->client_socket->opt_set(APR::SO_NONBLOCK, 0);

    my $bb_in  = APR::Brigade->new($c->pool, $c->bucket_alloc);
    my $bb_out = APR::Brigade->new($c->pool, $c->bucket_alloc);

    while (1) {
        my $rc = $c->input_filters->get_brigade($bb_in,
                                                Apache::MODE_GETLINE);
        last if $rc == APR::EOF;
        die APR::Error::strerror($rc) unless $rc == APR::SUCCESS;

        while (!$bb_in->is_empty) {
            my $bucket = $bb_in->first;

            $bucket->remove;

            if ($bucket->is_eos) {
                $bb_out->insert_tail($bucket);
                last;
            }

            if ($bucket->read(my $data)) {
                last if $data =~ /^[\r\n]+$/;
                $bucket = APR::Bucket->new(uc $data);
            }

            $bb_out->insert_tail($bucket);
        }

        $c->output_filters->fflush($bb_out);
    }

    $bb_in->destroy;
    $bb_out->destroy;

    Apache::OK;
}

1;
