use lib qw(../lib);
use ModPerl::MM ();
use Config;

my $prefix = ModPerl::MM::build_config()->apxs(-q => 'PREFIX');

my $libdir = "$prefix/lib";

my @libs = map "-l$_", qw(apr aprutil);

ModPerl::MM::WriteMakefile(
    'NAME'	   => 'APR',
    'VERSION_FROM' => 'APR.pm',
#XXX: no longer works with apr's goofy versioning scheme
#low priority to fix as nobody is using Perl APR bindings
#outside of httpd
#    'LIBS'         => ["-L$libdir @libs"],
#    'DEFINE'       => '-DMP_HAVE_APR_LIBS', #only if @libs are found
);
