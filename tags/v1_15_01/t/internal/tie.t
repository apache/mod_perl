use Apache::test;

skip_test unless $net::callback_hooks{PERL_TABLE_API};

print fetch "$PERL_DIR/tie_table.pl";
