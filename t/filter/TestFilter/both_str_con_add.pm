package TestFilter::both_str_con_add;

# insert an input filter which lowers the case of the data
# insert an output filter which adjusts s/modperl/mod_perl/

use strict;
use warnings FATAL => 'all';

use Apache::Connection ();
use APR::Bucket ();
use APR::Brigade ();
use APR::Util ();

use APR::Const -compile => qw(SUCCESS EOF);
use Apache::Const -compile => qw(OK MODE_GETLINE);

use Apache::Const -compile => qw(OK);

sub pre_connection {
    my Apache::Connection $c = shift;

    $c->add_input_filter(\&in_filter);
    $c->add_output_filter(\&out_filter);

    return Apache::OK;
}
sub in_filter {
    my $filter = shift;

    while ($filter->read(my $buffer, 1024)) {
        $filter->print(lc $buffer);
    }

    # test that $filter->ctx works here
    $filter->ctx(1);

    Apache::OK;
}

sub out_filter {
    my $filter = shift;

    while ($filter->read(my $buffer, 1024)) {
        $buffer =~ s/modperl/mod_perl/;
        $filter->print($buffer);
    }

    Apache::OK;
}

sub handler {
    my Apache::Connection $c = shift;

    my $bb = APR::Brigade->new($c->pool, $c->bucket_alloc);

    for (;;) {
        my $rv = $c->input_filters->get_brigade($bb,
                                                Apache::MODE_GETLINE);

        if ($rv != APR::SUCCESS or $bb->empty) {
            my $error = APR::strerror($rv);
            unless ($rv == APR::EOF) {
                warn "[echo_filter] get_brigade: $error\n";
            }
            $bb->destroy;
            last;
        }

        my $b = APR::Bucket::flush_create($c->bucket_alloc);
        $bb->insert_tail($b);
        $c->output_filters->pass_brigade($bb);
    }

    Apache::OK;
}

1;
__END__
<NoAutoConfig>
  <VirtualHost TestFilter::both_str_con_add>
      PerlPreConnectionHandler TestFilter::both_str_con_add::pre_connection
      PerlProcessConnectionHandler TestFilter::both_str_con_add
  </VirtualHost>
</NoAutoConfig>


