package TestDirective::perlloadmodule5;

# in this test we test an early mod_perl startup caused by an
# EXEC_ON_READ directive in the baseserver. In this test we have a
# mod_perl native directive before a non-native directive inside vhost
# section. Here mod_perl sets scfg for that vhost by itself.
#
# See also perlloadmodule4.pm, which is almost the same, but has no
# mod_perl native directive before a non-native directive in vhost. In
# that test the non-native mod_perl directive sets scfg on behalf of
# mod_perl in that vhost.
#
# see perlloadmodule6.pm for the case where mod_perl starts early, but
# from within the vhost.

use strict;
use warnings FATAL => 'all';

use Apache::CmdParms ();
use Apache::Module ();
use Apache::ServerUtil ();

use Apache::Const -compile => qw(OK);

use constant KEY => "MyTest5";

our @APACHE_MODULE_COMMANDS = ({ name => +KEY },);

sub MyTest5 {
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

# APACHE_TEST_CONFIG_ORDER 950

<Base>
    PerlLoadModule TestDirective::perlloadmodule5
</Base>
<VirtualHost TestDirective::perlloadmodule5>
    # here mod_perl sets the scfg by itself for this vhost
    PerlModule File::Spec
    MyTest5 "Vhost"
    <Location /TestDirective::perlloadmodule5>
        MyTest5 "Dir"
        SetHandler modperl
        PerlResponseHandler TestDirective::perlloadmodule5
    </Location>
</VirtualHost>
