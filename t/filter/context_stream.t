use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 1;

my $blocks  = 11;
my $invoked = 34;
my $sig = join "\n", "received $blocks complete blocks",
    "filter invoked $invoked times\n";
my $data = "#" x $blocks . "x" x $blocks;
my $expected = join "\n", $data, $sig;

{
    # test the filtering of the mod_perl response handler
    my $location = '/TestFilter::context_stream';
    my $response = GET_BODY $location;
    ok t_cmp($expected, $response, "context stream filter");
}
