package TestDirective::env;

use strict;
use warnings FATAL => 'all';

use Apache::Const -compile => 'OK';
use Apache::Test;
use Apache::TestUtil;

sub handler {
    my $r = shift;

    plan $r, tests => 4;

    ok t_cmp('env_dir1', env_get('srv1'),
             'per-dir override per-srv');

    ok t_cmp('env_srv2', env_get('srv2'),
             'per-srv');

    ok t_cmp('env_dir2', env_get('dir2'),
             'per-dir');

    #setup by Apache::TestRun
    ok t_cmp('test.host.name',
             $ENV{APACHE_TEST_HOSTNAME},
             'PassEnv');

    Apache::OK;
}

sub env_get {
    my($name, $r) = @_;
    my $key = 'TestDirective__env_' . $name;
    return $r ? $r->subprocess_env->get($key) : $ENV{$key};
}

1;
__END__
PerlOptions +SetupEnv

<Base>
    PerlSetEnv TestDirective__env_srv1 env_srv1

    PerlSetEnv TestDirective__env_srv2 env_srv2

    PerlPassEnv APACHE_TEST_HOSTNAME
</Base>

PerlSetEnv TestDirective__env_srv1 env_dir1

PerlSetEnv TestDirective__env_dir2 ToBeLost
PerlSetEnv TestDirective__env_dir2 env_dir2

