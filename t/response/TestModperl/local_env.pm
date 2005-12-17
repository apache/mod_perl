package TestModperl::local_env;

use strict;
use warnings FATAL => 'all';

use Apache2::Const -compile => 'OK';

sub handler {
    # This used to cause segfaults
    # Report: http://thread.gmane.org/gmane.comp.apache.mod-perl/22236
    # Fixed in: http://svn.apache.org/viewcvs.cgi?rev=357236&view=rev
    local %ENV;

    Apache2::Const::OK;
}

1;
__END__
SetHandler perl-script
