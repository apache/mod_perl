use lib qw(lib Apache-Test/lib);

use ModPerl::WrapXS ();

my $xs = ModPerl::WrapXS->new;

$xs->generate;

