use Apache::test;

skip_test unless $net::callback_hooks{PERL_TIE_TABLES};

print fetch "/perl/tie_table.pl";
