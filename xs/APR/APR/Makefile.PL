use lib qw(../lib);
use ModPerl::MM ();
use Config;

my $prefix = ModPerl::MM::build_config()->apxs(-q => 'PREFIX');

my $libdir = "$prefix/lib";

my @libs = map "-l$_", qw(apr aprutil);

ModPerl::MM::WriteMakefile(
    'NAME'	   => 'APR',
    'VERSION_FROM' => 'APR.pm',
    'LIBS'         => ["-L$libdir @libs"],
);
