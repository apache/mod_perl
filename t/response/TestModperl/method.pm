package TestModperl::method;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::Const -compile => 'OK';

sub handler : method {
    my($class, $r) = @_;

    plan $r, tests => 3;

    ok t_cmp(2, scalar @_,
             '@_ == 2');

    my $cmp_class = ref($class) || $class;

    ok t_cmp($cmp_class, $cmp_class,
             'handler class');

    ok t_cmp('/' . $cmp_class, $r->uri,
             '$r->uri eq __PACKAGE__');

    Apache::OK;
}

1;
__END__
