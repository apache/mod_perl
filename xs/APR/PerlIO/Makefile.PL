use lib qw(../lib);
use ModPerl::BuildMM ();

ModPerl::BuildMM::WriteMakefile(
    NAME => 'APR::PerlIO',
    VERSION_FROM => 'PerlIO.pm',
    OBJECT => 'PerlIO.o apr_perlio.o');

