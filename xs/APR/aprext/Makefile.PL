use strict;
use warnings;

use lib qw(../lib);
use ModPerl::BuildMM ();
use Apache::Build ();

my $srcdir = '../../../src/modules/perl';
my @names = map { "modperl_$_" } (qw(error bucket),
                                  map { "common_$_" } qw(util log));
my(@obj, @clean, %src);
for (@names) {
    push @obj, join '.', $_, 'o';
    my $cfile = join '.', $_, 'c';
    push @clean, $cfile;
    $src{$cfile} = "$srcdir/$cfile";
}

my @skip = qw(dynamic test);
push @skip, q{static} unless Apache::Build::WIN32;

my %args = (NAME          => 'aprext',
            VERSION_FROM  => '../APR/APR.pm',
            SKIP          =>  [ @skip ] ,
            LINKTYPE      =>  'static',
            OBJECT        => "@obj",
            clean         => { FILES => "@clean" },
	   );

ModPerl::BuildMM::WriteMakefile(%args);

sub MY::postamble {
    my $self = shift;
    my $string = $self->ModPerl::BuildMM::MY::postamble;

    $string .= join '', map {
        "$_: $src{$_}\n\t\$(CP) $src{$_} .\n";
    } keys %src;
    return $string;
}
