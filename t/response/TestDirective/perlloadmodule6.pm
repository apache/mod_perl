package TestDirective::perlloadmodule6;

# in this test we test an early mod_perl startup caused by an
# EXEC_ON_READ directive in vhost.

use strict;
use warnings FATAL => 'all';

use Apache::CmdParms ();
use Apache::Module ();
use Apache::ServerUtil ();

use Apache::Const -compile => qw(OK);

use constant KEY => "MyTest6";

our @APACHE_MODULE_COMMANDS = ({ name => +KEY },);

sub MyTest6 {
    my($self, $parms, $arg) = @_;
    $self->{+KEY} = $arg;
    unless ($parms->path) {
        my $srv_cfg = Apache::Module->get_config($self, $parms->server);
        $srv_cfg->{+KEY} = $arg;
    }
}

### response handler ###

use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::Server ();
use Apache::ServerUtil ();
use Apache::Module ();
use Apache::Test;
use Apache::TestUtil;

use Apache::Const -compile => qw(OK);

sub get_config {
    Apache::Module->get_config(__PACKAGE__, @_);
}

sub handler {
    my($r) = @_;
    my %secs = ();

    $r->content_type('text/plain');

    my $s = $r->server;
    my $dir_cfg = get_config($s, $r->per_dir_config);
    my $srv_cfg = get_config($s);

    plan $r, tests => 3;

    ok $s->is_virtual;

    ok t_cmp("Dir", $dir_cfg->{+KEY}, "Section");

    ok t_cmp("Vhost", $srv_cfg->{+KEY}, "Section");

    return Apache::OK;
}

1;
__END__

# XXX: we want to have this configuration section to come first
# amongst other perlloadmodule tests (<950), so we can test how
# mod_perl starts from vhost. but currently we can't because
# PerlSwitches from other tests are ignored, so the test suite fails
# to startup.
#
# tmp solution: ensure that it's configured *after* all other
# perlloadmodule tests
#
# APACHE_TEST_CONFIG_ORDER 951

<VirtualHost TestDirective::perlloadmodule6>
    PerlLoadModule TestDirective::perlloadmodule6
    MyTest6 "Vhost"
    <Location /TestDirective__perlloadmodule6>
        MyTest6 "Dir"
        SetHandler modperl
        PerlResponseHandler TestDirective::perlloadmodule6
    </Location>
</VirtualHost>
