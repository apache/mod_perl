use strict;
use warnings FATAL => 'all';

use Apache::TestRequest 'GET_BODY_ASSERT';
print GET_BODY_ASSERT "/TestAPI__request_rec/my_path_info?my_args=3";
