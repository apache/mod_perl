use strict;
use warnings FATAL => 'all';

# test BEGIN/END blocks's behavior

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

my %modules = (
    registry    => 'ModPerl::Registry',
    registry_ng => 'ModPerl::RegistryNG',
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

    ok t_cmp(
             "begin ok",
             req($same_interp, "$url?test=begin"),
             "$modules{$alias} is running BEGIN blocks on the first req",
            );

    ok t_cmp(
             "begin ok",
             req($same_interp, "$url?test=begin"),
             "$modules{$alias} is running BEGIN blocks on the second req",
            );

    ok t_cmp(
             "end ok",
             req($same_interp, "$url?test=end"),
             "$modules{$alias} is running END blocks on the first req",
            );

    ok t_cmp(
             "end ok",
             req($same_interp, "$url?test=end"),
             "$modules{$alias} is running END blocks on the second req",
            );
}

# To properly test BEGIN/END blocks in registry implmentations
# that do caching, we need to manually reset the registry* cache
# for each given script, before starting each group of tests.


for my $alias (grep !/^perlrun$/, @aliases) {
    my $url = "/same_interp/$alias/special_blocks.pl";
    my $same_interp = Apache::TestRequest::same_interp_tie($url);

    # clear the cache of the registry package for the script in $url
    req($same_interp, "$url?test=uncache");

    ok t_cmp(
             "begin ok",
             req($same_interp, "$url?test=begin"),
             "$modules{$alias} is running BEGIN blocks on the first req",
            );

    ok t_cmp(
             "",
             req($same_interp, "$url?test=begin"),
             "$modules{$alias} is not running BEGIN blocks on the second req",
            );

    # clear the cache of the registry package for the script in $url
    req($same_interp, "$url?test=uncache");

    ok t_cmp(
             "end ok",
             req($same_interp, "$url?test=end"),
             "$modules{$alias} is running END blocks on the first req",
            );

    ok t_cmp(
             "end ok",
             req($same_interp, "$url?test=end"),
             "$modules{$alias} is running END blocks on the second req",
            );

}

sub req {
    my($same_interp, $url) = @_;
    my $res = Apache::TestRequest::same_interp_do($same_interp,
                                                  \&GET, $url);
    return $res ? $res->content : undef;
}
