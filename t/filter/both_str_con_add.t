use strict;
use warnings FATAL => 'all';

use Test;
use Apache::TestUtil;
use Apache::TestRequest ();

my @test_strings = qw(MODPERL 2.0 RULES);

plan tests => 1 + @test_strings;

my $module = "TestFilter__both_str_con_add";
my $socket = Apache::TestRequest::vhost_socket($module);

ok $socket;

for my $str (@test_strings) {
    print $socket "$str\n";
    chomp(my $reply = <$socket>);
    $str = lc $str;
    $str =~ s/modperl/mod_perl/;
    ok t_cmp($str, $reply);
}
