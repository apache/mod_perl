use lib qw(../lib);
use ModPerl::BuildMM ();
use Config;

my $prefix = ModPerl::BuildMM::build_config()->apxs(-q => 'PREFIX');

# XXX: this works only with libapr 0.9.2+ (not on win32)
my @libs = grep $_, map { -x $_ && qx{$_ --link-ld --libs} }
    map { qq{$prefix/bin/$_-config} } qw(apr apu);
chomp @libs;

my $define = @libs ? '-DMP_HAVE_APR_LIBS' : '';

ModPerl::BuildMM::WriteMakefile(
    'NAME'	   => 'APR',
    'VERSION_FROM' => 'APR.pm',
    'LIBS'         => [join ' ', @libs],
    'DEFINE'       => $define,
);
