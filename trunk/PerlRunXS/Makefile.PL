use ExtUtils::MakeMaker;

use ExtUtils::testlib;
use lib qw(../blib/lib ../blib/arch ../lib);
         
use Apache::src ();

my $src = Apache::src->new;
WriteMakefile(
    'NAME'	=> 'Apache::PerlRunXS',
    'VERSION_FROM' => 'PerlRunXS.pm', # finds $VERSION
    'LIBS'	=> [''],   # e.g., '-lm' 
    'DEFINE'	=> '-g',     # e.g., '-DHAVE_SOMETHING' 
    'TYPEMAPS' => $src->typemaps,
    'INC'	=> $src->inc,     # e.g., '-I/usr/include/other' 
);
