use Apache::test;

skip_test unless $net::callback_hooks{PERL_STACKED_HANDLERS};
print fetch "http://$net::httpserver/chain/";
