# the handler is configured in modperl_extra.pl via
# Apache2->server->add_config
use Apache::TestRequest 'GET_BODY_ASSERT';

print GET_BODY_ASSERT "/apache2/add_config";
