# test the require

use Apache::Test ();
use File::Spec::Functions qw(catfile);

my $vars = Apache::Test::config()->{vars};
my $require = catfile $vars->{serverroot}, 'cgi-bin', 'local-conf.pl';

print "Content-type: text/plain\n\n";

# XXX: meanwhile we don't chdir to the script's dir
delete $INC{$require};
require $require;

print defined $test_require && $test_require;

