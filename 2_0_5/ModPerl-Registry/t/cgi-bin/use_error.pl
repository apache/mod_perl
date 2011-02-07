BEGIN {
    use Apache::TestUtil;
    t_server_log_error_is_expected();
}

use DoesNotExist ();

print "Content-type: text/plain\n\n";
print "this script is expected to fail";
