package TestModperl::subenv;

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use APR::Table ();

use Apache::Test;

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 19;

    my $env = $r->subprocess_env;
    ok $env;

    # subprocess_env in void context populates the same as +SetEnv
    {
        my $key = 'REMOTE_ADDR';
        ok_false($r, $key);
        $r->subprocess_env;
        ok_true($r, $key);
        ok $ENV{$key}; # mod_cgi emulation
    }

    {
        my $key = 'FOO';
        $env = $r->subprocess_env; #table may have been overlayed
        $env->set($key => 1);
        ok_true($r, $key);
        ok ! $ENV{$key}; # shouldn't affect %ENV

        $r->subprocess_env($key => undef);
        ok_false($r, $key);

        $r->subprocess_env($key => 1);
        ok_true($r, $key);
        ok ! $ENV{$key}; # shouldn't affect %ENV
    }

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

