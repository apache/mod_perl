use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

use Config;

use constant HAS_ITHREADS => ($] >= 5.008001 && $Config{useithreads});

plan tests => 1, need
    {"perl 5.8.1 or higher w/ithreads enabled is required" => HAS_ITHREADS};

{
    my $expected = join "\n", map("thread $_", 1..4), "parent";
    my $url = "/registry_modperl_handler/ithreads_io_n_tie.pl";
    my $received = GET_BODY_ASSERT($url);
    ok t_cmp $received, $expected;
}
