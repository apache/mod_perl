use strict;
use warnings;

use lib qw(../lib);
use ModPerl::BuildMM ();
use Apache::Build ();
use Config;

use constant WIN32   => Apache::Build::WIN32;
use constant SOLARIS => $^O eq 'solaris';

my %args = (
    'NAME'         => 'APR',
    'VERSION_FROM' => 'APR.pm',
);

my $libs = '';
my $build = ModPerl::BuildMM::build_config();

if (my $apr_bindir = $build->apr_bindir()) {

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

if (SOLARIS && $libs) {
    # EU::MM sets LD_RUN_PATH (for linking) based on -L options in LIBS.
    # LD_RUN_PATH is getting overridden by the specified -R path.
    # The -R specified is from the perl config's lddflags.
    # Therefore -R has to be added with the appropriate paths rather
    # than using LD_RUN_PATH, because it gets overridden.

    # make sure that all -L, -R from libs are moved
    # to the beginning of lddflags.
    my $extralddflags = join " ", $libs =~ /(-[LR]\S+)/g;

    # -R makes sure that these paths will be used
    $extralddflags =~ s{-L(\S+)}{-L$1 -R$1}g;
    $args{LDDLFLAGS} = $extralddflags . " " . $build->perl_config('lddlflags');

    # -R are now copied to LDDFLAGS, but leave -L's in LIBS --
    # EU::MM needs it.
    $libs =~ s{-R\S+}{}g;
}

$args{LIBS} = [$libs] if $libs;

ModPerl::BuildMM::WriteMakefile(%args);
