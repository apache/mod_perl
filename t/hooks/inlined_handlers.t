use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 2;

my $location = "/TestHooks__inlined_handlers";

t_debug "getting the same interp ID for $location";
my $same_interp = Apache::TestRequest::same_interp_tie($location);

my $skip = $same_interp ? 0 : 1;
my $expected = "ok";
for (1..2) {
    my $received = get_body($same_interp, \&GET, $location);
    $skip++ unless defined $received;
    skip_not_same_interp(
        $skip,
        $received,
        $expected,
        "anonymous handlers in httpd.conf test"
    );
}

# if we fail to find the same interpreter, return undef (this is not
# an error)
sub get_body {
    my $res = eval {
        Apache::TestRequest::same_interp_do(@_);
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
        skip "Skip couldn't find the same interpreter", 0;
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
