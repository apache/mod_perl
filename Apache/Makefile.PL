use ExtUtils::MakeMaker;
use Config;

$apache_1_3_inc = '-I../$(APACHE_SRC)/main -I$(APACHE_SRC)/main -I../$(APACHE_SRC)/os/unix -I$(APACHE_SRC)/os/unix';

WriteMakefile(
    NAME	=> "Apache",
    VERSION_FROM => "Apache.pm",
    INC => '-I../src -I../src/modules/perl -I../$(APACHE_SRC) -I../$(APACHE_SRC)/regex -I$(APACHE_SRC) -I$(APACHE_SRC)/regex '.$apache_1_3_inc,
);

