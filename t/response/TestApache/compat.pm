package TestApache::compat;

# these Apache::compat tests are all run on the server
# side and validated on the client side. See also TestApache::compat2.

use strict;
use warnings FATAL => 'all';

use Apache::TestUtil;
use Apache::Test ();

use Apache::compat ();
use Apache::Constants qw(OK M_POST DECLINED);

use subs qw(ok debug);
my $gr;

sub handler {
    my $r = shift;
    $gr = $r;

    $r->send_http_header('text/plain');

    my $cfg = Apache::Test::config();
    my $vars = $cfg->{vars};

    my %data;
    if ($r->method_number == M_POST) {
        %data = $r->content;
    }
    else {
        %data = $r->Apache::args;
    }

    return DECLINED unless exists $data{test};

    if ($data{test} eq 'content' || $data{test} eq 'args') {
        $r->print("test $data{test}");
    }

    OK;
}

sub ok    { $gr->print($_[0] ? "ok\n" : "nok\n"); }
sub debug { $gr->print("# $_\n") for @_; }

1;
__END__
PerlOptions +GlobalRequest
