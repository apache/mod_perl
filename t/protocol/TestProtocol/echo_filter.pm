package TestProtocol::echo_filter;

# see also TestFilter::both_str_con_add

use strict;
use warnings FATAL => 'all';

use Apache::Connection ();
use APR::Socket ();
use APR::Bucket ();
use APR::Brigade ();
use APR::Error ();

use base qw(Apache::Filter);

use APR::Const    -compile => qw(SUCCESS EOF SO_NONBLOCK);
use Apache::Const -compile => qw(OK MODE_GETLINE);

use constant BUFF_LEN => 1024;

sub uc_filter : FilterConnectionHandler {
    my $filter = shift;

    while ($filter->read(my $buffer, BUFF_LEN)) {
        $filter->print(uc $buffer);
    }

    return Apache::OK;
}

sub handler {
    my $c = shift;

    # starting from Apache 2.0.49 several platforms require you to set
    # the socket to a blocking IO mode
    $c->client_socket->opt_set(APR::SO_NONBLOCK, 0);

    my $bb = APR::Brigade->new($c->pool, $c->bucket_alloc);

    while (1) {
        my $rc = $c->input_filters->get_brigade($bb, Apache::MODE_GETLINE);
        last if $rc == APR::EOF;
        die APR::Error::strerror($rc) unless $rc == APR::SUCCESS;

        # fflush is the equivalent of the following 3 lines of code:
        #
        # my $b = APR::Bucket::flush_create($c->bucket_alloc);
        # $bb->insert_tail($b);
        # $c->output_filters->pass_brigade($bb);
        $c->output_filters->fflush($bb);
    }

    $bb->destroy;

    Apache::OK;
}

1;
__END__
PerlModule              TestProtocol::echo_filter
PerlOutputFilterHandler TestProtocol::echo_filter::uc_filter

