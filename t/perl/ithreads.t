# perl/ithreads2 is a similar test but is running from within a
# virtual host with its own perl interpreter pool (+Parent)

use Apache::TestRequest 'GET_BODY_ASSERT';
print GET_BODY_ASSERT "/TestPerl__ithreads";
