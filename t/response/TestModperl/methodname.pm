package TestModperl::methodname;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::Const -compile => 'OK';

use TestModperl::method ();

#no : method attribute required when -> config syntax is used
sub response {
    TestModperl::method::handler(@_);
}

1;
__END__
PerlResponseHandler TestModperl::methodname->response
