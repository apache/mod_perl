use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

use lib map {($_, "../$_") } qw(lib Apache-Test/lib);

use ModPerl::BuildMM ();
use Apache::TestSmokePerl ();

# enable 'make test|clean'
use Apache::TestMM qw(test clean);

# prerequisites
my %require = (
    "Apache::Test" => "", # any version will do?
);

my @scripts = qw(t/TEST);

# accept the configs from comman line
Apache::TestMM::filter_args();
Apache::TestMM::generate_script('t/TEST');

# t/SMOKE
Apache::TestSmokePerl->generate_script;

ModPerl::BuildMM::WriteMakefile(
    NAME         => 'ModPerl::Registry',
    VERSION_FROM => 'lib/ModPerl/RegistryCooker.pm',
    PREREQ_PM    => \%require,
    clean        => {
        FILES => "@{ clean_files() }",
    });

sub clean_files {
    return [@scripts];
}
