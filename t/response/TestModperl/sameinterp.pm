package TestModperl::sameinterp;

use warnings FATAL => 'all';
use strict;

use Apache2::RequestIO ();

use Apache::TestHandler ();

use Apache2::Const -compile => qw(OK);

my $value = '';

sub handler {
    my $r = shift;

    # test the actual global data
    $value = Apache::TestHandler::same_interp_counter();
    $r->puts($value);

    Apache2::Const::OK;
}

1;
__END__
PerlFixupHandler Apache::TestHandler::same_interp_fixup
