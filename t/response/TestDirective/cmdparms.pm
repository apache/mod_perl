package TestDirective::cmdparms;

use strict;
use warnings FATAL => 'all';

use Apache::CmdParms ();
use Apache::Module ();

use Apache::Test;
use Apache::TestUtil;

use Apache::Const -compile => qw(
    ACCESS_CONF
    M_GET
    M_POST
    M_PUT
    M_DELETE
    OK
    OR_AUTHCFG
    OR_FILEINFO
    OR_INDEXES
    OR_LIMIT
    OR_OPTIONS
    RSRC_CONF
    NOT_IN_LOCATION
);

use constant KEY => "TestCmdParms";

our @APACHE_MODULE_COMMANDS = (
    { 
        name        => +KEY,
        cmd_data    => 'cmd_data',
        errmsg      => 'errmsg',
    },
);
  
my @methods = qw(cmd context directive info limited override path
                 pool server temp_pool);
  
sub TestCmdParms {
    my($self, $parms, $args) = @_;
    my $srv_cfg = $self->get_config($parms->server);
    foreach my $method (@methods) {
        $srv_cfg->{$args}{$method} = $parms->$method();
    }
    $srv_cfg->{$args}{check_ctx} = 
        $parms->check_cmd_context(Apache::NOT_IN_LOCATION);
}

sub get_config {
    my($self, $s) = (shift, shift);
    Apache::Module->get_config($self, $s, @_);
}

### response handler ###
sub handler : method {
    my($self, $r) = @_;
    my $override; 
    my $srv_cfg = $self->get_config($r->server);

    plan $r, tests => 6 + ( 8 * keys(%$srv_cfg) );

    foreach my $cfg (values %$srv_cfg) {
        ok t_cmp(ref($cfg->{cmd}), 'Apache::Command', 'cmd');
        ok t_cmp(ref($cfg->{context}), 'Apache::ConfVector', 'context');
        ok t_cmp(ref($cfg->{directive}), 'Apache::Directive', 'directive');
        ok t_cmp(ref($cfg->{pool}), 'APR::Pool', 'pool');
        ok t_cmp(ref($cfg->{temp_pool}), 'APR::Pool', 'temp_pool');
        ok t_cmp(ref($cfg->{server}), 'Apache::ServerRec', 'server');
        ok t_cmp($cfg->{limited}, -1, 'limited');
        ok t_cmp($cfg->{info}, 'cmd_data', 'cmd_data');
    }    

    my $vhost = $srv_cfg->{Vhost};

    $override = Apache::RSRC_CONF   |
                Apache::OR_INDEXES  |
                Apache::OR_FILEINFO |
                Apache::OR_OPTIONS;

    ok t_cmp($vhost->{override}, $override, 'override');
    ok t_cmp($vhost->{path}, undef, 'path');
    ok t_cmp($vhost->{check_ctx}, undef, 'check_cmd_ctx');

    my $loc = $srv_cfg->{Location};

    $override = Apache::ACCESS_CONF |
                Apache::OR_INDEXES  |
                Apache::OR_AUTHCFG  |
                Apache::OR_FILEINFO |
                Apache::OR_OPTIONS  |
                Apache::OR_LIMIT;

    ok t_cmp($loc->{override}, $override, 'override');
    ok t_cmp($loc->{path}, '/TestDirective__cmdparms', 'path');
    ok t_cmp($loc->{check_ctx}, KEY . 
              ' cannot occur within <Location> section', 'check_cmd_ctx');

    return Apache::OK;
}

1;
__END__

# APACHE_TEST_CONFIG_ORDER 950

<Base>
PerlLoadModule TestDirective::cmdparms
TestCmdParms "Vhost"
</Base>

TestCmdParms "Location"
