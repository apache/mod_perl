package TestProtocol::echo_bbs2;

# similar to TestProtocol::echo_bbs but here re-using one bucket
# brigade for input and output, using flatten to slurp all the data in
# the bucket brigade, and cleanup to get rid of the old buckets

# XXX: ideally $bb->cleanup should be used here and no create/destroy
# bb every time the loop is entered should be done. But it segfaults
# on certain setups:
# http://marc.theaimsgroup.com/?l=apache-modperl-dev&m=108967266419527&w=2

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

    my $last = 0;
    while (1) {
        my $bb_in  = APR::Brigade->new($c->pool, $c->bucket_alloc);
        my $bb_out = APR::Brigade->new($c->pool, $c->bucket_alloc);

        my $rc = $c->input_filters->get_brigade($bb_in,
                                                Apache::MODE_GETLINE);
        last if $rc == APR::EOF;
        die APR::Error::strerror($rc) unless $rc == APR::SUCCESS;

        next unless $bb_in->flatten(my $data);
        #warn "read: [$data]\n";
        last if $data =~ /^[\r\n]+$/;

        # transform data here
        my $bucket = APR::Bucket->new($bb_in->bucket_alloc, uc $data);
        $bb_out->insert_tail($bucket);

        $c->output_filters->fflush($bb_out);

        # XXX: add DESTROY and remove explicit calls
        $bb_in->destroy;
        $bb_out->destroy;
    }

    Apache::OK;
}

1;
