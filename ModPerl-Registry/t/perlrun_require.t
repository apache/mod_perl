use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw(GET);

# XXX: use the same server setup to test

plan tests => 2;

my $url = "/same_interp/perlrun/perlrun_require.pl";
my $same_interp = Apache::TestRequest::same_interp_tie($url);

for (1..2) {
    # should not fail on the second request
    ok t_cmp(
        "1",
        req($same_interp, $url),
        "PerlRun requiering and external lib with subs",
       );
}

sub req {
    my($same_interp, $url) = @_;
    my $res = Apache::TestRequest::same_interp_do($same_interp,
                                                  \&GET, $url);
    return $res ? $res->content : undef;
}
