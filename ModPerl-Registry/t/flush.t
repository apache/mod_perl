use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw(GET_BODY);

plan tests => 1, have 'Compress::Zlib', 'deflate',
    have_min_apache_version("2.0.49");

#XXX which release the mod_deflate bug is fixed in? Apache/2.0.49? 
# should probably submit a bug report and use the bug id here so
# others can track the problem

require Compress::Zlib;

my $url = "/registry_bb_deflate/flush.pl";

my $expected = "yet another boring test string";
my $received = GET_BODY $url, 'Accept-encoding' => 'gzip';
my $decompressed = Compress::Zlib::memGunzip($received);

ok t_cmp(
    $expected,
    $decompressed,
    "test flush body"
   );

