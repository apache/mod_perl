use Apache::test;
use Apache::src ();

unless (Apache::src->mmn_eq) {
    skip_test;
}

print fetch "/perl/module.pl";

