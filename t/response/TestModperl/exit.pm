package TestModperl::exit;

use strict;
use warnings FATAL => 'all';

use ModPerl::Util ();

use Apache::Test;

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, test => 1;

    ok 1;

    ModPerl::Util::exit();

    #not reached
    ok 2;

    Apache::OK;
}

1;
__END__

