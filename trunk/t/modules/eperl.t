
use Apache::test;

skip_test unless have_module "Parse::ePerl";

print "1..1\n";

test 1, simple_fetch "/env.iphtml";

