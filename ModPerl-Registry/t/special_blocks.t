use strict;
use warnings FATAL => 'all';

# test BEGIN/END blocks's behavior

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

my %modules = (
    registry    => 'ModPerl::Registry',
    registry_bb => 'ModPerl::RegistryBB',
    perlrun     => 'ModPerl::PerlRun',
);

my @aliases = sort keys %modules;

plan tests => @aliases * 4;

{
    # PerlRun always run BEGIN/END since it's never cached

    my $alias = "perlrun";
    my $url = "/same_interp/$alias/special_blocks.pl";
    my $same_interp = Apache::TestRequest::same_interp_tie($url);

    # if one sub-test has failed to run on the same interpreter, skip
    # the rest in the same group
    my $skip = 0;

    my $res = get_body($same_interp, "$url?begin");
    $skip++ unless defined $res;
    skip_not_same_intrep(
        $skip,
        "begin ok",
        $res,
        "$modules{$alias} is running BEGIN blocks on the first request",
    );

    $res = $skip ? undef : get_body($same_interp, "$url?begin");
    $skip++ unless defined $res;
    skip_not_same_intrep(
        $skip,
        "begin ok",
        $res,
        "$modules{$alias} is running BEGIN blocks on the second request",
    );

    $res = $skip ? undef : get_body($same_interp, "$url?end");
    $skip++ unless defined $res;
    skip_not_same_intrep(
        $skip,
        "end ok",
        $res,
        "$modules{$alias} is running END blocks on the third request",
    );

    $res = $skip ? undef : get_body($same_interp, "$url?end");
    $skip++ unless defined $res;
    skip_not_same_intrep(
        $skip,
        "end ok",
        $res,
        "$modules{$alias} is running END blocks on the fourth request",
    );
}

# To properly test BEGIN/END blocks in registry implmentations
# that do caching, we need to manually reset the registry* cache
# for each given script, before starting each group of tests.


for my $alias (grep !/^perlrun$/, @aliases) {
    my $url = "/same_interp/$alias/special_blocks.pl";
    my $same_interp = Apache::TestRequest::same_interp_tie($url);

    # if one sub-test has failed to run on the same interpreter, skip
    # the rest in the same group
    my $skip = 0;

    # clear the cache of the registry package for the script in $url
    my $res = get_body($same_interp, "$url?uncache");
    $skip++ unless defined $res;

    $res = $skip ? undef : get_body($same_interp, "$url?begin");
    $skip++ unless defined $res;
    skip_not_same_intrep(
        $skip,
        "begin ok",
        $res,
        "$modules{$alias} is running BEGIN blocks on the first request",
    );

    $res = $skip ? undef : get_body($same_interp, "$url?begin");
    $skip++ unless defined $res;
    t_debug($res);
    skip_not_same_intrep(
        $skip,
        "",
        $res,
        "$modules{$alias} is not running BEGIN blocks on the second request",
    );

    $same_interp = Apache::TestRequest::same_interp_tie($url);
    $skip = 0;

    # clear the cache of the registry package for the script in $url
    $res = get_body($same_interp, "$url?uncache");
    $skip++ unless defined $res;

    $res = $skip ? undef : get_body($same_interp, "$url?end");
    $skip++ unless defined $res;
    skip_not_same_intrep(
        $skip,
        "end ok",
        $res,
        "$modules{$alias} is running END blocks on the first request",
    );

    $res = $skip ? undef : get_body($same_interp, "$url?end");
    $skip++ unless defined $res;
    skip_not_same_intrep(
        $skip,
        "end ok",
        $res,
        "$modules{$alias} is running END blocks on the second request",
    );
}

# if we fail to find the same interpreter, return undef (this is not
# an error)
sub get_body {
    my($same_interp, $url) = @_;
    my $res = eval {
        Apache::TestRequest::same_interp_do($same_interp, \&GET, $url);
    };
    return undef if $@ && $@ =~ /unable to find interp/;
    die $@ if $@;
    return $res->content if defined $res;
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
