package TestModperl::printf;

use strict;
use warnings FATAL => 'all';

use Apache::RequestIO ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    my $tests = 3;

    $r->printf("1..%d\n", $tests);

    $r->printf("ok");

    $r->printf(" %d\n", 1);

    my $fmt = "%s%s %d\n";
    $r->printf($fmt, qw(o k), 2);

    my @a = ("ok %d%c", 3, ord("\n"));
    $r->PRINTF(@a);

    Apache::OK;
}

1;
__END__

