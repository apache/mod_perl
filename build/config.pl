use lib qw(lib);
use lib qw(Apache-Test/lib);

use Apache::Build ();
use Apache::TestConfig ();

my $build_config = Apache::Build->build_config;

print "using $INC{'Apache/BuildConfig.pm'}\n";

print "Makefile.PL options:\n";
for (sort keys %$build_config) {
    next unless /^MP_/;
    printf "    %-20s => %s\n", $_, $build_config->{$_};
}

my $test_config = Apache::TestConfig->new;
my $httpd = $test_config->{vars}->{httpd};

print "\n$httpd -V:\n";
system "$httpd -V";

my $perl = $build_config->{MODPERL_PERLPATH};

print "\n$perl -V:\n";
system "$perl -V";

