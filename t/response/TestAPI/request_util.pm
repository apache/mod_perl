package TestAPI::request_util;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::RequestUtil ();
use Apache::MPM ();
use Apache::Log ();
use APR::Pool ();

use Apache::Const -compile => 'OK';

my %status_lines = (
   200 => '200 OK',
   400 => '400 Bad Request',
   500 => '500 Internal Server Error',
);

sub handler {
    my $r = shift;

    plan $r, tests => (scalar keys %status_lines) + 11;

    ok $r->default_type;

    my $document_root = $r->document_root;

    ok $document_root;

    if (!Apache::MPM->is_threaded) {
        ok t_cmp($document_root, $r->document_root('/tmp/foo'));
        ok t_cmp('/tmp/foo', $r->document_root($document_root));
    }
    else {
        eval { $r->document_root('/tmp/foo') };
        ok t_cmp($@, qr/Can't run.*in the threaded env/, 
                 "document_root is read-only under threads");
        ok 1;
    }

    ok $r->get_server_name;

    ok $r->get_server_port;

    ok $r->get_limit_req_body || 1;

    ok $r->is_initial_req;

    my $sig = $r->psignature("Here is the sig: ");
    t_debug $sig;
    ok $sig;

    my $pattern =
        qr!(?s)GET /TestAPI__request_util.*Host:.*200 OK.*Content-Type:!;

    ok t_cmp($r->as_string,
             $pattern,
             "test for the request_line, host, status, and few " .
             "headers that should always be there");

    while (my($code, $line) = each %status_lines) {
        ok t_cmp(Apache::RequestUtil::get_status_line($code),
                 $line,
                 "Apache::RequestUtil::get_status_line($code)");
    }

    if (Apache::MPM->is_threaded) {
        eval { $r->child_terminate() };
        ok t_cmp($@, qr/Can't run.*in a threaded mpm/, "child_terminate");
    }
    else {
        t_server_log_error_is_expected();
        ok $r->child_terminate() || 1;
        $r->pool->cleanup_register(
            sub {
                my $r = shift;
                $r->log_error("Process $$ terminates itself\n");
            }, $r);
    }

    Apache::OK;
}

1;
