package TestAPI::server_util;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use File::Spec::Functions qw(canonpath catfile);

use Apache::RequestRec ();
use Apache::ServerUtil ();
use Apache::Process ();

use APR::Pool ();

use Apache::Const -compile => 'OK';

my $serverroot = Apache::Test::config()->{vars}->{serverroot};

our @ISA = qw(Apache::RequestRec);

sub new {
    my $class = shift;
    my $r = shift;
    bless { r => $r }, $class;
}

sub handler {

    my $r = shift;

    my %pools = ( 
        '$r->pool'                       => $r->pool, 
        '$r->connection->pool'           => $r->connection->pool,
        '$r->server->process->pool'      => $r->server->process->pool,
        '$r->server->process->pconf'     => $r->server->process->pconf,
        'Apache->server->process->pconf' => Apache->server->process->pconf,
        'APR::Pool->new'                 => APR::Pool->new,
    );

    my %objects = ( 
        '$r'                   => $r,
        '$r->connection'       => $r->connection,
        '$r->server'           => $r->server,
        '__PACKAGE__->new($r)' => __PACKAGE__->new($r),
    );

    plan $r, tests => 11     +
        (scalar keys %pools) +
        (scalar keys %objects);

    {
        my $s = $r->server;
        my @expected = qw(ModPerl::Test::exit_handler);
        my @handlers =
            @{ $s->get_handlers('PerlChildExitHandler') || []};
        ok t_cmp(scalar(@handlers), scalar(@expected), "get_handlers");
    }

    # syntax - an object or pool is required
    t_debug("Apache::server_root_relative() died");
    eval { my $dir = Apache::server_root_relative() };
    t_debug("\$\@: $@");
    ok $@;

    t_debug("Apache->server_root_relative() died");
    eval { my $dir = Apache->server_root_relative() };
    ok $@;

    # syntax - first argument must be an object, not a class
    t_debug("Apache->server_root_relative('conf') died");
    eval { my $dir = Apache->server_root_relative('conf') };
    ok $@;

    foreach my $p (keys %pools) {

        ok t_filepath_cmp(canonpath(Apache::server_root_relative($pools{$p},
                              'conf')),
                          catfile($serverroot, 'conf'),
                          "Apache:::server_root_relative($p, 'conf')");
    }

    # dig out the pool from valid objects
    foreach my $obj (keys %objects) {

        ok t_filepath_cmp(canonpath($objects{$obj}->server_root_relative('conf')),
                          catfile($serverroot, 'conf'),
                          "$obj->server_root_relative('conf')");
    }

    # syntax - unrecognized objects don't segfault
    {
        my $obj = bless {}, 'Apache::Foo';
        eval { Apache::server_root_relative($obj, 'conf') };

        ok t_cmp($@,
                 qr/server_root_relative.*no .* key/,
                 "Apache::server_root_relative(\$obj, 'conf')");
    }

    # no file argument gives ServerRoot
    ok t_filepath_cmp(canonpath($r->server_root_relative),
                      canonpath($serverroot),
                      '$r->server_root_relative()');

    ok t_filepath_cmp(canonpath(Apache::server_root_relative($r->pool)),
                      canonpath($serverroot),
                      'Apache::server_root_relative($r->pool)');

    # Apache::server_root is also the ServerRoot constant
    ok t_filepath_cmp(canonpath(Apache::server_root),
                      canonpath($r->server_root_relative),
                      'Apache::server_root');

    {
        # absolute paths should resolve to themselves
        my $dir = $r->server_root_relative('logs');

        ok t_filepath_cmp($r->server_root_relative($dir),
                          $dir,
                          "\$r->server_root_relative($dir)");
    }

    t_debug('Apache::exists_config_define');
    ok Apache::exists_config_define('MODPERL2');
    ok ! Apache::exists_config_define('FOO');

    Apache::OK;
}

1;

__END__
