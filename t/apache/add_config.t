# the handler is configured in modperl_extra.pl via
# Apache->server->add_config
use Apache::TestRequest 'GET';

my $res = GET "/apache/add_config";
if ($res->is_success) {
    print $res->content;
}
else {
    die "server side has failed (response code: ", $res->code, "),\n",
        "see t/logs/error_log for more details\n";
}
