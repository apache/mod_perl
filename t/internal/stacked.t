use Apache::test;

skip_test unless $net::callback_hooks{PERL_STACKED_HANDLERS};
die "can't open http://$net::httpserver/$net::perldir/stacked\n" 
    unless simple_fetch "/stacked";
print fetch "/chain/";
