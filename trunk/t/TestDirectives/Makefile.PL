use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

BEGIN {
    use lib qw{../../lib};
}

use strict;
use Apache::src ();
use Apache::ExtUtils qw(command_table);

my $class = 'Apache::TestDirectives';

my @directives = (
   [TestCmd => "Two TestCmd args"],
   [AnotherCmd => "Stuff for another command"],
   [YAC => "Yet another comand"],
   [CmdIterate => "No limit here"],
   ["<Container" => "whatever"],
   ["</Container>" => "end whatever"],
);

my $proto_perl2c = Apache::ExtUtils->proto_perl2c;

while(my($pp,$cp) = each %$proto_perl2c) {
    push @directives, [$cp, "Test for $cp"];
}

command_table $class, \@directives;

WriteMakefile(
    'NAME'	=> $class,
    'VERSION_FROM' => 'TestDirectives.pm', # finds $VERSION
    'LIBS'	=> [''],   # e.g., '-lm' 
    'DEFINE'	=> '',     # e.g., '-DHAVE_SOMETHING' 
    'INC'	=> Apache::src->new->inc,
);
