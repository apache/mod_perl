
use Apache::test;

skip_test unless have_module "Apache::Sandwich";

my $n = 0; 

print "1..1\n";

test ++$n, simple_fetch "/subr/";

