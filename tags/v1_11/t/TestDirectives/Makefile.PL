use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

BEGIN {
    use lib qw{../../blib/lib ../../blib/arch ../../lib};
}

use strict;
use Apache::src ();
use Apache::ExtUtils ();

my $class = 'Apache::TestDirectives';

my @directives = qw(TestCmd);
my $fh = IO::File->new(">TestDirectives.xs") or die $!;
my $xs = Apache::ExtUtils->xs_cmd_table($class, \@directives);  
print $fh $xs;

close $fh;

WriteMakefile(
    'NAME'	=> $class,
    'VERSION_FROM' => 'TestDirectives.pm', # finds $VERSION
    'LIBS'	=> [''],   # e.g., '-lm' 
    'DEFINE'	=> '',     # e.g., '-DHAVE_SOMETHING' 
    'INC'	=> Apache::src->new->inc,
);
