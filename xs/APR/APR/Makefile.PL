use lib qw(../lib);
use ModPerl::BuildMM ();
use Config;

my $prefix = ModPerl::BuildMM::build_config()->apxs(-q => 'PREFIX');

# XXX: this works only with libapr 0.9.2+ (not on win32)
my @libs = grep $_, map { -x $_ && qx{$_ --link-ld --libs} }
    map { qq{$prefix/bin/$_-config} } qw(apr apu);
chomp @libs;
my $libs = join ' ', @libs;

# fix for broken older apu-config script 0.9.2 (httpd 2.0.43)
$libs =~ s/-laprutil([^-]*)/-laprutil-0$1/ if $libs =~ /-lapr-0/;

ModPerl::BuildMM::WriteMakefile(
    'NAME'	   => 'APR',
    'VERSION_FROM' => 'APR.pm',
    'LIBS'         => [$libs],
);
