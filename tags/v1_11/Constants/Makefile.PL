use ExtUtils::MakeMaker;
use Config;

$mp_version = MM->parse_version("../Makefile.PL");

$apache_1_3_inc = join ' ', map { 
    join '', ' -I../$(APACHE_SRC)/', $_, ' -I$(APACHE_SRC)/', $_;
} qw(include main os/unix);

WriteMakefile(
    NAME	=> "Apache::Constants",
    VERSION_FROM => "Constants.pm",
    INC => '-I../src -I../src/modules/perl -I$(APACHE_SRC) -I../$(APACHE_SRC) '.$apache_1_3_inc .
	      qq{ -DSERVER_SUBVERSION=\\"mod_perl/$mp_version\\"},
);

