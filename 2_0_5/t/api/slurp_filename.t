use Apache::TestRequest 'GET_BODY_ASSERT';

# we want r->filename to be "/slurp/slurp.pl", even though the
# response handler is TestAPI::slurp_filename

print GET_BODY_ASSERT "/slurp/slurp.pl";
