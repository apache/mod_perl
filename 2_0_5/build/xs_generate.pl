use lib qw(lib Apache-Test/lib);

use Apache::TestConfig (); # needed to resolve circular use dependency

use ModPerl::WrapXS ();

my $xs = ModPerl::WrapXS->new;

$xs->generate;

