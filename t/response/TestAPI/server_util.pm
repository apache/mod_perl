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

    my %status_lines = (
       200 => '200 OK',
       400 => '400 Bad Request',
       500 => '500 Internal Server Error',
    );
    plan $r, tests => (scalar keys %pools) +
                      (scalar keys %objects) + 
                      (scalar keys %status_lines) + 11;

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

        ok t_cmp(catfile($serverroot, 'conf'),
                 canonpath(Apache::server_root_relative($pools{$p},
                     'conf')),
                 "Apache:::server_root_relative($p, 'conf')");
    }

    # dig out the pool from valid objects
    foreach my $obj (keys %objects) {

        ok t_cmp(catfile($serverroot, 'conf'),
                 canonpath($objects{$obj}->server_root_relative('conf')),
                 "$obj->server_root_relative('conf')");
    }

    # syntax - unrecognized objects don't segfault
    {
        my $obj = bless {}, 'Apache::Foo';
        eval { Apache::server_root_relative($obj, 'conf') };

        ok t_cmp(qr/server_root_relative.*no .* key/,
                 $@,
                 "Apache::server_root_relative(\$obj, 'conf')");
    }

    # no file argument gives ServerRoot
    ok t_cmp(canonpath($serverroot),
             canonpath($r->server_root_relative),
             '$r->server_root_relative()');

    ok t_cmp(canonpath($serverroot),
             canonpath(Apache::server_root_relative($r->pool)),
             'Apache::server_root_relative($r->pool)');

    # Apache::server_root is also the ServerRoot constant
    ok t_cmp(canonpath(Apache::server_root),
             canonpath($r->server_root_relative),
             'Apache::server_root');

    {
        # absolute paths should resolve to themselves
        my $dir = $r->server_root_relative('logs');

        ok t_cmp($r->server_root_relative($dir),
                 $dir,
                 "\$r->server_root_relative($dir)");
    }

    t_debug('registering method FOO');
    ok Apache::method_register($r->server->process->pconf, 'FOO');

    t_debug('Apache::exists_config_define');
    ok Apache::exists_config_define('MODPERL2');
    ok ! Apache::exists_config_define('FOO');

    while (my($code, $line) = each %status_lines) {
        ok t_cmp($line,
                 Apache::get_status_line($code),
                 "Apache::get_status_line($code)");
    }

    Apache::OK;
}

1;

__END__
