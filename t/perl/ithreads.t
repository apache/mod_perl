# perl/ithreads2 is a similar test but is running from within a
# virtual host with its own perl interpreter pool (+Parent)

use Config;

use Apache::Test;
use Apache::TestRequest 'GET_BODY_ASSERT';

# XXX: at the moment this test randomly fails, making it impossible to
# debug, so skip it for now and get back to work on it later.

# perl < 5.6.0 fails to compile code with 'shared' attributes, so we must skip
# it here.
#unless ($] >= 5.008001 && $Config{useithreads}) {
#    plan tests => 1, need
#        {"perl 5.8.1 or higher w/ithreads enabled is required" => 0};
#}
plan tests => 1, under_construction;

print GET_BODY_ASSERT "/TestPerl__ithreads";
