BEGIN {
    use Apache::TestUtil;
    t_server_log_error_is_expected();
}
my $r = shift;
$r->status(404);
$r->print("Content-type: text/plain\n\n");
$r->print(no_such_func());
