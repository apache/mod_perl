use lib qw(lib);

use ModPerl::WrapXS ();

my $xs = ModPerl::WrapXS->new;

$xs->generate;

