use lib qw(../lib);
use ModPerl::BuildMM ();

ModPerl::BuildMM::WriteMakefile(
    NAME => 'Apache::Const',
    VERSION_FROM => 'Const.pm',
);
