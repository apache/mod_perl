use Apache::test;

skip_test unless $net::callback_hooks{PERL_TIE_TABLES};

print fetch "$PERL_DIR/tie_table.pl";
