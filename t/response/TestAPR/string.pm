package TestAPR::string;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use APR::String ();

use Apache::Const -compile => 'OK';

my %size_string = (
    '-1'            => "  - ",
    0               => "  0 ",
    42              => " 42 ",
    42_000          => " 41K",
    42_000_000      => " 40M",
#    42_000_000_000   => "40G",
);

sub handler {
    my $r = shift;

    plan $r, tests => scalar keys %size_string;

    t_debug("size_string");
    while (my($k, $v) = each %size_string) {
        ok t_cmp($v, APR::String::format_size($k));
    }

    Apache::OK;
}

1;
__END__
