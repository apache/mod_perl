use strict;
use warnings FATAL => 'all';

# run tests through the same interpreter, even if the server is
# running more than one

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 12;

my $url = "/TestModperl__sameinterp";

# test the tie and re-tie
for (1..2) {
    my $same_interp = Apache::TestRequest::same_interp_tie($url);
    ok $same_interp;

    my $value = 1;
    my $skip  = 0;
    # test GET over the same same_interp
    for (1..2) {
        $value++;
        my $res = req($same_interp, \&GET, $url, foo => 'bar');
        $skip++ unless defined $res;
        skip_not_same_intrep(
            $skip,
            $value,
            defined $res && $res->content,
            "GET over the same interp"
        );
    }
}

{
    # test POST over the same same_interp
    my $same_interp = Apache::TestRequest::same_interp_tie($url);
    ok $same_interp;

    my $value = 1;
    my $skip  = 0;
    for (1..2) {
        $value++;
        my $content = join ' ', 'ok', $_ + 3;
        my $res = req($same_interp, \&POST, $url, content => $content);
        $skip++ unless defined $res;
        skip_not_same_intrep(
            $skip,
            $value,
            defined $res && $res->content,
            "POST over the same interp"
        );
    }
}

{
    # test HEAD over the same same_interp
    my $same_interp = Apache::TestRequest::same_interp_tie($url);
    ok $same_interp;

    my $value = 1;
    my $skip  = 0;
    for (1..2) {
        $value++;
        my $res = req($same_interp, \&HEAD, $url);
        $skip++ unless defined $res;
        skip_not_same_intrep(
            $skip,
            $same_interp,
            defined $res && $res->header(Apache::TestRequest::INTERP_KEY),
            "HEAD over the same interp"
        );
    }
}

# if we fail to find the same interpreter, return undef (this is not
# an error)
sub req {
    my($same_interp, $url) = @_;
    my $res = eval {
        Apache::TestRequest::same_interp_do(@_);
    };
    return undef if $@ && $@ =~ /unable to find interp/;
    die $@ if $@;
    return $res;
}

# make the tests resistant to a failure of finding the same perl
# interpreter, which happens randomly and not an error.
# the first argument is used to decide whether to skip the sub-test,
# the rest of the arguments are passed to 'ok t_cmp';
sub skip_not_same_intrep {
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
