package TestModperl::interp;

use warnings FATAL => 'all';
use strict;

use APR::UUID ();
use Apache::Const -compile => qw(OK NOT_FOUND SERVER_ERROR);

use constant INTERP => 'X-PerlInterpreter';

my $interp_id = "";
my $value = 0;

sub fixup {
    my $r = shift;
    my $interp = $r->headers_in->get(INTERP);
    my $rc = Apache::OK;

    unless ($interp) {
        #shouldn't be requesting this without an INTERP header
        return Apache::SERVER_ERROR;
    }

    my $id = $interp_id;
    if ($interp eq 'init') { #first request for an interpreter instance
        #unique id for this instance
        $interp_id = $id = APR::UUID->new->format;
        $value = 0; #reset our global data
    }
    elsif ($interp ne $interp_id) {
        #this is not the request interpreter instance
        $rc = Apache::NOT_FOUND;
    }

    #so client can save the created instance id or check the existing value
    $r->headers_out->set(INTERP, $id);

    return $rc;
}

sub handler {
    my $r = shift;

    #test the actual global data
    $value++;
    $r->puts("ok $value\n");

    Apache::OK;
}

1;
__END__
PerlFixupHandler TestModperl::interp::fixup
