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
    my $res = get_body($same_interp, $url);
    skip_not_same_interp(
        !defined($res),
        "1",
        $res,
        "PerlRun requiering and external lib with subs",
    );
}

# if we fail to find the same interpreter, return undef (this is not
# an error)
sub get_body {
    my($same_interp, $url) = @_;
    my $res = eval {
        Apache::TestRequest::same_interp_do($same_interp, \&GET, $url);
    };
    return undef if $@ =~ /unable to find interp/;
    return $res->content if $res;
    die $@ if $@;
}

# make the tests resistant to a failure of finding the same perl
# interpreter, which happens randomly and not an error.
# the first argument is used to decide whether to skip the sub-test,
# the rest of the arguments are passed to 'ok t_cmp';
sub skip_not_same_interp {
    my $skip_cond = shift;
    if ($skip_cond) {
        skip "Skip couldn't find the same interpreter";
    }
    else {
        my($package, $filename, $line) = caller;
        # trick ok() into reporting the caller filename/line when a
        # sub-test fails in sok()
        return eval <<EOE;
#line $line $filename
    ok &t_cmp;
EOE
    }
}
