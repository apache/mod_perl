package TestDirective::setupenv;

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    $ENV{QS} = $r->args if $r->args;

    while (my($key, $val) = each %ENV) {
        next unless $key and $val;
        $r->puts("$key=$val\n");
    }

    Apache::OK;
}

1;
__END__
PerlOptions +SetupEnv

