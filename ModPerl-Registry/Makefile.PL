require 5.6.0;

use ExtUtils::MakeMaker;

use lib qw(lib ../Apache-Test/lib);

# enable 'make test|clean'
use Apache::TestMM qw(test clean);

# prerequisites
my %require =
  (
   "Apache::Test" => "", # any version will do?
  );

my @scripts = qw(t/TEST);

# accept the configs from comman line
Apache::TestMM::filter_args();
Apache::TestMM::generate_script('t/TEST');

WriteMakefile
    (
     NAME         => 'ModPerl::Registry',
     VERSION_FROM => 'lib/ModPerl/RegistryCooker.pm',
     PREREQ_PM    => \%require,
     clean        => {
                      FILES => "@{ clean_files() }",
                     },
    );

sub clean_files {
    return [@scripts];
}
