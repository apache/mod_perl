use lib qw(../lib);
use ModPerl::MM ();

ModPerl::MM::WriteMakefile(
    NAME => 'APR::PerlIO',
    VERSION_FROM => 'PerlIO.pm',
    OBJECT => 'PerlIO.o apr_perlio.o');

