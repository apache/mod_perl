use ExtUtils::MakeMaker;

use lib qw(../lib);
use Apache::src ();
my $src = Apache::src->new;

WriteMakefile(
    'NAME'	=> 'Apache::Tie',
    'VERSION_FROM' => 'Tie.pm', 
    'INC'	=> $src->inc,
    'TYPEMAPS'  => $src->typemaps,
);
