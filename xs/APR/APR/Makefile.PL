use strict;
use warnings;

use lib qw(../lib);
use ModPerl::BuildMM ();
use Apache::Build ();
use Config;

use constant WIN32 => Apache::Build::WIN32;

my $libs = '';
if (my $apr_bindir = ModPerl::BuildMM::build_config()->apr_bindir()) {

    # XXX: this works only with libapr 0.9.2+
    my $ext = WIN32 ? '.bat' : '';
    my @libs = grep $_, map { -x $_ && qx{$_ --link-ld --libs} }
        map { qq{$apr_bindir/$_-config$ext} } qw(apr apu);
    chomp @libs;
    $libs = join ' ', @libs;
}

if (WIN32) {
    $libs =~ s{/libpath:}{-L}g;
    $libs =~ s{(\w+)\.lib}{-l$1}g;
}

ModPerl::BuildMM::WriteMakefile(
    'NAME'	   => 'APR',
    'VERSION_FROM' => 'APR.pm',
    'LIBS'         => [$libs],
);
