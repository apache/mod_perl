use lib qw(../lib);
use ModPerl::MM ();

ModPerl::MM::WriteMakefile(
    NAME => 'APR::Const',
    VERSION_FROM => 'Const.pm',
);
