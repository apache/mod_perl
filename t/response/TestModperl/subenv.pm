package TestModperl::subenv;

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use APR::Table ();

use Apache::Test;

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 16;

    my $env = $r->subprocess_env;
    ok $env;

    # subprocess_env in void context populates the same as +SetEnv
    ok_false($r, 'REMOTE_ADDR');
    $r->subprocess_env; 
    ok_true($r, 'REMOTE_ADDR');

    $env = $r->subprocess_env; #table may have been overlayed

    $env->set(FOO => 1);
    ok_true($r, 'FOO');

    $r->subprocess_env(FOO => undef);
    ok_false($r, 'FOO');

    $r->subprocess_env(FOO => 1);
    ok_true($r, 'FOO');

    Apache::OK;
}

sub ok_true {
    my($r, $key) = @_;

    my $env = $r->subprocess_env;
    ok $env->get($key);
    ok $env->{$key};
    ok $r->subprocess_env($key);
}

sub ok_false {
    my($r, $key) = @_;

    my $env = $r->subprocess_env;
    ok ! $env->get($key);
    ok ! $env->{$key};
    ok ! $r->subprocess_env($key);
}

1;
__END__
PerlOptions -SetupEnv

