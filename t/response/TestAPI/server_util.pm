package TestAPI::server_util;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use File::Spec::Functions qw(canonpath catfile);

use Apache::RequestRec ();
use Apache::ServerRec ();
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

    plan $r, tests => 17;

    {
        my $s = $r->server;
        my @expected = qw(ModPerl::Test::exit_handler);
        my @handlers =
            @{ $s->get_handlers('PerlChildExitHandler') || []};
        ok t_cmp(scalar(@handlers), scalar(@expected), "get_handlers");
    }

    t_debug('Apache::ServerUtil::exists_config_define');
    ok Apache::ServerUtil::exists_config_define('MODPERL2');
    ok ! Apache::ServerUtil::exists_config_define('FOO');

    t_debug('registering method FOO');
    ok $r->server->method_register('FOO');

    server_root_relative_tests($r);

    my $base_server_pool = Apache::ServerUtil::base_server_pool();
    ok $base_server_pool->isa('APR::Pool');

    # this will never run since it's not registered in the parent
    # process
    $base_server_pool->cleanup_register(sub { Apache::OK });
    ok 1;

    Apache::OK;
}


# 11 sub-tests
sub server_root_relative_tests {
    my $r = shift;

    my %pools = (
        '$r->pool'                       => $r->pool,
        '$r->connection->pool'           => $r->connection->pool,
        '$r->server->process->pool'      => $r->server->process->pool,
        '$r->server->process->pconf'     => $r->server->process->pconf,
        'Apache->server->process->pconf' => Apache->server->process->pconf,
        'APR::Pool->new'                 => APR::Pool->new,
    );

    # syntax - an object or pool is required
    t_debug("Apache::ServerUtil::server_root_relative() died");
    eval { my $dir = Apache::ServerUtil::server_root_relative() };
    t_debug("\$\@: $@");
    ok $@;

    foreach my $p (keys %pools) {
        # we will leak memory here when calling the function with a
        # pool whose life is longer than of $r, but it doesn't matter
        # for the test
        ok t_filepath_cmp(
            canonpath(Apache::ServerUtil::server_root_relative($pools{$p},
                                                               'conf')),
            catfile($serverroot, 'conf'),
            "Apache::ServerUtil:::server_root_relative($p, 'conf')");
    }

    # syntax - unrecognized objects don't segfault
    {
        my $obj = bless {}, 'Apache::Foo';
        eval { Apache::ServerUtil::server_root_relative($obj, 'conf') };

        ok t_cmp($@,
                 qr/p is not of type APR::Pool/,
                 "Apache::ServerUtil::server_root_relative(\$obj, 'conf')");
    }

    # no file argument gives ServerRoot
    {
        my $server_root_relative = 
            Apache::ServerUtil::server_root_relative($r->pool);

        ok t_filepath_cmp(canonpath($server_root_relative),
                          canonpath($serverroot),
                          'server_root_relative($pool)');

        # Apache::ServerUtil::server_root is also the ServerRoot constant
        ok t_filepath_cmp(canonpath(Apache::ServerUtil::server_root),
                          canonpath($server_root_relative),
                          'Apache::ServerUtil::server_root');

    }

    {
        # absolute paths should resolve to themselves
        my $dir1 = Apache::ServerUtil::server_root_relative($r->pool, 'logs');
        my $dir2 = Apache::ServerUtil::server_root_relative($r->pool, $dir1);

        ok t_filepath_cmp($dir1, $dir2, "absolute path");
    }
}

1;

__END__
