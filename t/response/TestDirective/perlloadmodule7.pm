package TestDirective::perlloadmodule7;

# in this test we test an early mod_perl startup caused by an
# EXEC_ON_READ directive in vhost.

use strict;
use warnings FATAL => 'all';

use Apache2::Module ();

use Apache2::Const -compile => qw(OK);

use constant KEY => "MyTest7";

my @directives = ({ name => +KEY },);

Apache2::Module::add(__PACKAGE__, \@directives);

sub MyTest7 {
    my($self, $parms, $arg) = @_;
    $self->{+KEY} = $arg;
}

### response handler ###

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => qw(OK);

sub handler {
    my($r) = @_;

    plan $r, tests => 1;

    ok 1;

    return Apache2::Const::OK;
}

1;
__END__

<NoAutoConfig>
# APACHE_TEST_CONFIG_ORDER 950
PerlLoadModule TestDirective::perlloadmodule7

<Location /TestDirective__perlloadmodule7>
    MyTest7 test
    SetHandler modperl
    PerlResponseHandler TestDirective::perlloadmodule7
</Location>
</NoAutoConfig>
