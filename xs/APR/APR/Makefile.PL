use ExtUtils::MakeMaker;

use lib qw(../lib);
use ModPerl::MM ();
use Config;

my $root = ModPerl::MM::build_config('dir') || "";
my $srclib = "$root/srclib";
my $apr = "$srclib/apr";

my @libs;
if ($root) {
    @libs = join ' ',
      "-L$apr/.libs -lapr",
        "-L$srclib/apr-util/.libs -laprutil",
          "-L$srclib/expat-lite/.libs -lexpat",
            "-L$apr/shmem/unix/mm/.libs -lmm";
}

ModPerl::MM::WriteMakefile(
    'NAME'	=> 'APR',
    'VERSION_FROM' => 'APR.pm',
    'LIBS' => \@libs,
);

sub MY::const_loadlibs {
    my $self = shift;

    my $string = $self->MM::const_loadlibs;
    return $string unless $Config{gccversion}; #XXX

    my $wa = '-Wl,--whole-archive';
    my $nwa = '-Wl,--no-whole-archive';

    $string =~ s/(LDLOADLIBS\s*=\s*)(.*)/$1$wa $2 $nwa/;
    $string;
}
