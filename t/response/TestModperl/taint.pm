package TestModperl::taint;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::RequestIO ();
use Apache::RequestUtil ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 4;

    ok t_cmp(1, ${^TAINT}, "\${^TAINT}");

    eval { ${^TAINT} = 0 };
    ok t_cmp(qr/read-only/, $@, "\${^TAINT} is read-only");

    ok t_cmp(1, $Apache::__T, "\$Apache::__T");

    eval { $Apache::__T = 0 };
    ok t_cmp(qr/read-only/, $@, "\$Apache::__T is read-only");

    Apache::OK;
}

1;
__END__
