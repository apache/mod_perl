
use Apache::test;

skip_test unless have_module "HTML::Embperl";

print "1..1\n";

my $res = simple_fetch "/lists.ehtml";
test 1, $res;
$net::callback_hooks{MMN} ||= 19980413;
unless($res) {
    if($net::callback_hooks{MMN} >= 19980413) {
	warn "\n>>> NOTE: Be sure to rebuild HTML::Embperl against Apache 1.3b6+\n";
	warn ">>> Try 'make test' again after doing so.\n";
	sleep 2;
    }
}
