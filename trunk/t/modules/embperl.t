use Apache::src ();
use Apache::test;

skip_test unless have_module "HTML::Embperl";

unless (Apache::src->mmn_eq) {
    skip_test;
}

print "1..1\n";

my $res = simple_fetch "/lists.ehtml";
test 1, $res;
