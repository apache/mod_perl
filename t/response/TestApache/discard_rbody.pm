package TestApache::discard_rbody;

# test $r->discard_request_body when the input body wasn't read at
# all, read partially or completely.

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::Connection ();
use Apache::Filter ();
use APR::Brigade ();

use Apache::Const -compile => qw(OK MODE_READBYTES);
use APR::Const    -compile => qw(SUCCESS BLOCK_READ);

use constant IOBUFSIZE => 8192;

sub handler {
    my $r = shift;

    $r->content_type('text/plain');
    my $test = $r->args;

    if ($test eq 'none') {
        # don't read the request body
    }
    elsif ($test eq 'partial') {
        # read some of request POSTed data (IOBUFSIZE bytes),
        # but not all of it
        my $filters = $r->input_filters();
        my $ba = $r->connection->bucket_alloc;
        my $bb = APR::Brigade->new($r->pool, $ba);
        my $rv = $filters->get_brigade($bb, Apache::MODE_READBYTES,
                                       APR::BLOCK_READ, IOBUFSIZE);
        die "failed to read partial data" unless $rv == APR::SUCCESS;
    }
    elsif ($test eq 'all') {
        # consume all of the request body
        my $data = ModPerl::Test::read_post($r);
        die "failed to consume all the data" unless length($data) == 100000;
    }

    # now get rid of the rest of the input data should work, no matter
    # how little or how much of the body was read
    $r->discard_request_body;

    $r->print($test);

    Apache::OK;
}

1;
