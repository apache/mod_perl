# the handler is configured in modperl_extra.pl via
# Apache->server->add_config
use Apache::TestRequest 'GET_BODY_ASSERT';

print GET_BODY_ASSERT "/apache/add_config";
