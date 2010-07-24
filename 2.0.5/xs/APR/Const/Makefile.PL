use lib qw(../lib);
use ModPerl::BuildMM ();

ModPerl::BuildMM::WriteMakefile(
    NAME => 'APR::Const',
    VERSION_FROM => 'Const.pm',
);
