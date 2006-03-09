package TestAPI::add_config;

use strict;
use warnings FATAL => 'all';

use Apache2::Access ();
use Apache2::CmdParms ();
use Apache2::RequestUtil ();
use Apache2::Directive ();
use Apache2::ServerUtil ();
use base qw(Apache2::Module);

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => qw(
    OK
    DECLINED
    :options
);

use constant KEY        => "TestAddConfig";
use constant APACHE22   => have_min_apache_version('2.2.0');

my @directives = (
    {
        name        => KEY,
        cmd_data    => 'cmd_data',
        errmsg      => 'errmsg',
    },
);

Apache2::Module::add(__PACKAGE__, \@directives);

sub TestAddConfig {
    my ($self, $parms, $args) = @_;
    my $srv_cfg = $self->get_config($parms->server);
    $srv_cfg->{override_opts} = $parms->override_opts();
}

sub map2storage {
    my $r = shift;

    my $o = APACHE22 ? '=All,SymLinksIfOwnerMatch' : '';

    eval {
        $r->add_config(['AllowOverride All Options'.$o]);
    };
    $r->pnotes(add_config1 => "$@");

    eval {
        $r->add_config(['Options ExecCGI'], -1, '/', 0);
    };
    $r->pnotes(add_config2 => "$@");

    eval {
        my $directory = join '/', ('', $r->document_root,
                                   'TestAPI__add_config');
        $r->add_config(["<Directory $directory>",
                      'AllowOverride All Options'.$o,
                      '</Directory>'
                      ], -1, '');
    };
    $r->pnotes(add_config4 => "$@");

    return Apache2::Const::DECLINED;
}

sub fixup {
    my ($r) = @_;

    eval {
        $r->add_config(['Options ExecCGI'], -1, '/',
                       Apache2::Const::OPT_EXECCGI);
    };
    $r->pnotes(add_config3 => "$@");

    return Apache2::Const::DECLINED;
}

sub handler : method {
    my ($self, $r) = @_;
    my $cf = $self->get_config($r->server);

    plan $r, tests => 7;

    ok t_cmp $r->pnotes('add_config1'), qr/.+\n/;
    ok t_cmp $r->pnotes('add_config2'), (APACHE22 ? qr/.+\n/ : '');
    ok t_cmp $r->pnotes('add_config3'), '';
    ok t_cmp $r->pnotes('add_config4'), '';

    my $default_opts = 0;
    unless (APACHE22) {
        $default_opts = Apache2::Const::OPT_UNSET |
                        Apache2::Const::OPT_INCNOEXEC |
                        Apache2::Const::OPT_MULTI;
    }
   
    my $expect = $default_opts | Apache2::Const::OPT_ALL 
                               | Apache2::Const::OPT_SYM_OWNER;

    ok t_cmp $cf->{override_opts}, $expect;
    ok t_cmp $r->allow_override_opts, $expect;
    ok t_cmp $r->allow_options, Apache2::Const::OPT_EXECCGI;

    return Apache2::Const::OK;
}

1;
__END__

# APACHE_TEST_CONFIG_ORDER 950
<NoAutoConfig>
    <VirtualHost TestAPI::add_config>
        PerlModule TestAPI::add_config
        AccessFileName htaccess
        SetHandler modperl
        PerlResponseHandler TestAPI::add_config
        PerlMapToStorageHandler TestAPI::add_config::map2storage
        PerlFixupHandler TestAPI::add_config::fixup
    </VirtualHost>
</NoAutoConfig>
