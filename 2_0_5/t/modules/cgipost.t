use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw(POST_BODY_ASSERT);

my $module = 'TestModules::cgipost';
my $url = '/' . Apache::TestRequest::module2path($module);

my @data = (25, 50, 75, 100, 125, 150);

plan tests => scalar(@data), need_min_module_version(CGI => 3.08);

foreach my $post (@data) {
    my %param = ();

    foreach my $key (1 .. $post) {
      $param{$key} = 'data' x $key;
    }

    my $post_data = join '&', map { "$_=$param{$_}" }
                              sort { $a <=> $b } keys %param;
    my $expected  = join ':', map { $param{$_}      }
                              sort { $a <=> $b } keys %param;

    my $e_length = length $expected;

    my $received = POST_BODY_ASSERT $url, content => $post_data;

    my $r_length = length $received;

    t_debug "expected $e_length bytes, received $r_length bytes\n";
    ok ($expected eq $received);
}

