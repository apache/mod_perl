use strict;
use warnings;

use lib qw(../lib);
use ModPerl::BuildMM ();
use Config;

my $libs = '';
if (my $apr_bindir = ModPerl::BuildMM::build_config()->apr_bindir()) {

    # XXX: this works only with libapr 0.9.2+ (not on win32)
    my @libs = grep $_, map { -x $_ && qx{$_ --link-ld --libs} }
        map { qq{$apr_bindir/$_-config} } qw(apr apu);
    chomp @libs;
    $libs = join ' ', @libs;

    # fix for broken older apu-config script 0.9.2 (httpd 2.0.43)
    $libs =~ s/-laprutil(?!-)/-laprutil-0/ if $libs =~ /-lapr-0/;
}


ModPerl::BuildMM::WriteMakefile(
    'NAME'	   => 'APR',
    'VERSION_FROM' => 'APR.pm',
    'LIBS'         => [$libs],
);
