use ExtUtils::MakeMaker;
use Config;

$mp_version = MM->parse_version("../Makefile.PL");

$apache_1_3_inc = '-I../$(APACHE_SRC)/main -I$(APACHE_SRC)/main -I../$(APACHE_SRC)/os/unix -I$(APACHE_SRC)/os/unix';

WriteMakefile(
    NAME	=> "Apache::Constants",
    VERSION_FROM => "Constants.pm",
    INC => '-I../src -I../src/modules/perl -I../$(APACHE_SRC) -I../$(APACHE_SRC)/regex -I$(APACHE_SRC)  -I$(APACHE_SRC)/regex ' . $apache_1_3_inc .
	      qq{ -DSERVER_SUBVERSION=\\"mod_perl/$mp_version\\"},
);

