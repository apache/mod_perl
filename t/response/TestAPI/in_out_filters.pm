package TestAPI::in_out_filters;

# testing: $r->input_filters and $r->output_filters
# it's possible to read a POST data and send a response body w/o using
# $r->read/$r->print

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestUtil ();

use APR::Brigade ();
use APR::Bucket ();
use Apache::Filter ();

use Apache::Const -compile => qw(OK DECLINED MODE_READBYTES);
use APR::Const    -compile => qw(SUCCESS BLOCK_READ);

use constant IOBUFSIZE => 8192;

sub handler {
    my $r = shift;

    return Apache::DECLINED unless $r->method_number == Apache::M_POST;

    $r->content_type("text/plain");

    my $data = read_request_body($r);
    send_response_body($r, lc($data));

    Apache::OK;
}

sub send_response_body {
    my($r, $data) = @_;

    my $bb = APR::Brigade->new($r->pool,
                               $r->connection->bucket_alloc);

    my $b = APR::Bucket->new($data);
    $bb->insert_tail($b);
    $r->output_filters->fflush($bb);
    $bb->destroy;
}

sub read_request_body {
    my $r = shift;
    my $debug = shift || 0;

    my $bb = APR::Brigade->new($r->pool,
                               $r->connection->bucket_alloc);

    my $data = '';
    my $seen_eos = 0;
    my $count = 0;
    do {
        $r->input_filters->get_brigade($bb, Apache::MODE_READBYTES,
                                       APR::BLOCK_READ, IOBUFSIZE);

        $count++;
        warn "read_post: bb $count\n" if $debug;

        for (my $b = $bb->first; $b; $b = $bb->next($b)) {
            if ($b->is_eos) {
                warn "read_post: EOS bucket:\n" if $debug;
                $seen_eos++;
                last;
            }

            if ($b->read(my $buf)) {
                warn "read_post: DATA bucket: [$buf]\n" if $debug;
                $data .= $buf;
            }

            $b->remove; # optimization to reuse memory
        }

    } while (!$seen_eos);

    $bb->destroy;

    return $data;
}

1;
__END__
