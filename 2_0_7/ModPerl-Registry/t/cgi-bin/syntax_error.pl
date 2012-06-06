BEGIN {
    use Apache::TestUtil;
    t_server_log_error_is_expected();
}

print "Content-type: text/plain\n\n";

# the following syntax error is here on purpose!

lkj;\;

print "done";
