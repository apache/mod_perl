package TestProtocol::echo_bbs2;

# similar to TestProtocol::echo_bbs but here re-using one bucket
# brigade for input and output, using flatten to slurp all the data in
# the bucket brigade, and cleanup to get rid of the old buckets

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

    my $bb = APR::Brigade->new($c->pool, $c->bucket_alloc);

    my $last = 0;
    while (1) {
        my $bb_in  = APR::Brigade->new($c->pool, $c->bucket_alloc);
        my $rc = $c->input_filters->get_brigade($bb_in,
                                                Apache::MODE_GETLINE);
        if ($rc != APR::SUCCESS && $rc != APR::EOF) {
            my $error = APR::Error::strerror($rc);
            warn __PACKAGE__ . ": get_brigade: $error\n";
            last;
        }
        last if $rc == APR::EOF;

        next unless $bb_in->flatten(my $data);
        $bb->cleanup;
        #warn "read: [$data]\n";
        last if $data =~ /^[\r\n]+$/;

        # transform data here
        my $bucket = APR::Bucket->new(uc $data);
        $bb->insert_tail($bucket);

        $c->output_filters->fflush($bb);
    }

    $bb->destroy;

    Apache::OK;
}

1;
