
use Apache::test;

skip_test unless have_module "HTML::Embperl";

print "1..1\n";

test 1, simple_fetch "/lists.ehtml";

