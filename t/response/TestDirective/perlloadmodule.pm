package TestDirective::perlloadmodule;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::Const -compile => qw(OK OR_ALL RSRC_CONF TAKE1 TAKE23);

use Apache::CmdParms ();
use Apache::Module ();

our @APACHE_MODULE_COMMANDS = (
    {
     name => 'MyTest',
     func => __PACKAGE__ . '::MyTest',
     req_override => Apache::RSRC_CONF,
#     req_override => 'RSRC_CONF', #test 1.x compat for strings
#     args_how => Apache::TAKE23,
     args_how => 'TAKE23', #test 1.x compat for strings
     errmsg => 'A test',
    },
    {
     name => 'MyOtherTest',
     cmd_data => 'some info',
    },
    {
     name => 'ServerTest',
     req_override => Apache::RSRC_CONF,
    }
);

sub DIR_CREATE {
    my($class, $parms) = @_;

    bless {
	path => $parms->path || "/",
    }, $class;
}

sub merge {
    my($base, $add) = @_;

    my %new = ();

    @new{keys %$base, keys %$add} =
	(values %$base, values %$add);

    return bless \%new, ref($base);
}

sub DIR_MERGE {
    my $class = ref $_[0];
#    warn "$class->DIR_MERGE\n";
    merge(@_);
}

#sub SERVER_MERGE {
#    my $class = ref $_[0];
#    warn "$class->SERVER_MERGE\n";
#    merge(@_);
#}

sub SERVER_CREATE {
    my($class, $parms) = @_;
#    warn "$class->SERVER_CREATE\n";
    return bless {
	name => __PACKAGE__,
    }, $class;
}

sub MyTest {
    my($self, $parms, @args) = @_;
    $self->{MyTest} = \@args;
    $self->{MyTestInfo} = $parms->info;
}

sub MyOtherTest {
    my($self, $parms, $arg) = @_;
    $self->{MyOtherTest} = $arg;
    $self->{MyOtherTestInfo} = $parms->info;
}

sub ServerTest {
    my($self, $parms, $arg) = @_;
    my $srv_cfg = $self->get_config($parms->server);
    $srv_cfg->{ServerTest} = $arg;
}

sub get_config {
    my($self, $s) = (shift, shift);
    Apache::Module->get_config($self, $s, @_);
}

sub handler : method {
    my($self, $r) = @_;

    my $s = $r->server;
    my $dir_cfg = $self->get_config($s, $r->per_dir_config);
    my $srv_cfg = $self->get_config($s);

    plan $r, tests => 9;

    t_debug("per-dir config:", $dir_cfg);
    t_debug("per-srv config:", $srv_cfg);

    ok $dir_cfg->isa($self);
    ok $srv_cfg->isa($self);

    my $path = $dir_cfg->{path};

    ok t_cmp(qr{^$path}, $r->uri,
             'r->uri =~ parms->path');

    ok t_cmp($self, $srv_cfg->{name},
             '$self eq $srv_cfg->{name}');

    ok t_cmp('value', $dir_cfg->{MyOtherTest},
             'MyOtherTest value');

    ok t_cmp('some info', $dir_cfg->{MyOtherTestInfo},
             'MyOtherTest cmd_data');

    ok t_cmp(['one', 'two'], $dir_cfg->{MyTest},
             'MyTest one two');

    ok ! $dir_cfg->{MyTestInfo};

    ok t_cmp('per-server', $srv_cfg->{ServerTest});

    Apache::OK;
}

1;
__END__

# APACHE_TEST_CONFIG_ORDER 950

<Base>
    PerlLoadModule TestDirective::perlloadmodule

    MyTest one two
    ServerTest per-server
</Base>

MyOtherTest value

