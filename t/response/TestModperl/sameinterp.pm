package TestModperl::sameinterp;

use warnings FATAL => 'all';
use strict;

use Apache::Const -compile => qw(OK);

my $value = '';

sub handler {
    my $r = shift;

    # test the actual global data
    $value = Apache::TestHandler::same_interp_counter();
    $r->puts($value);

    Apache::OK;
}

1;
__END__
PerlFixupHandler Apache::TestHandler::same_interp_fixup
