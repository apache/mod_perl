use lib qw(../lib);
use ModPerl::MM ();

ModPerl::MM::WriteMakefile(
    NAME => 'Apache::Const',
    VERSION_FROM => 'Const.pm',
);
