use ExtUtils::MakeMaker;
use Config;

$apache_1_3_inc = join ' ', map { 
    join '', ' -I../$(APACHE_SRC)/', $_, ' -I$(APACHE_SRC)/', $_;
} qw(include main os/unix);

WriteMakefile(
    NAME	=> "Apache::URI",
    VERSION_FROM => "URI.pm",
    INC => '-I../src -I../src/modules/perl -I$(APACHE_SRC) -I../$(APACHE_SRC) '.$apache_1_3_inc,
);

