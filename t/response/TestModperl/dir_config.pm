package TestModperl::dir_config;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 12;

    #Apache::RequestRec::dir_config tests

    # this test doesn't test all $r->dir_config->*(), since
    # dir_config() returns a generic APR::Table which is tested in
    # apr/table.t.

    # object test
    my $dir_config = $r->dir_config;
    ok defined $dir_config && ref($dir_config) eq 'APR::Table';

    # PerlAddVar ITERATE2 test
    {
        my $key = make_key('1');
        my @received = $dir_config->get($key);
        my @expected = qw(1_SetValue 2_AddValue 3_AddValue 4_AddValue);

        ok t_cmp(\@expected, \@received,
                 'testing PerlAddVar ITERATE2');
    }

    {
        my $key = make_key('0');

        # object interface test in a scalar context (for a single
        # PerlSetVar key)
        ok t_cmp('SetValue0',
                 $dir_config->get($key),
                 qq{\$dir_config->get("$key")});

        #  direct fetch test in a scalar context (for a single
        #  PerlSetVar)
        ok t_cmp('SetValue0',
                 $r->dir_config($key),
                 qq{\$r->dir_config("$key")});
    }

    # test non-existent key
    {
        my $key = make_key();

        ok t_cmp(undef,
                 $r->dir_config($key),
                 qq{\$r->dir_config("$key")});
    }

    # test set interface
    {
        my $key = make_key();
        my $val = "DirConfig";

        $r->dir_config($key => $val);

        ok t_cmp($val,
                 $r->dir_config($key),
                 qq{\$r->dir_config($key => "$val")});
    }

    # test unset interface
    {
        my $key = make_key();

        $r->dir_config($key => 'whatever');
        $r->dir_config($key => undef);

        ok t_cmp(undef,
                 $r->dir_config($key),
                 qq{\$r->dir_config($key => undef)});
    }

    # test PerlSetVar set in base config
    {
        my $key = make_key('_set_in_Base');

        ok t_cmp("BaseValue",
                 $r->dir_config($key),
                 qq{\$r->dir_config("$key")});
    }

    #Apache::Server::dir_config tests

    my $s = $r->server;

    # this test doesn't test all $s->dir_config->*(), since
    # dir_config() returns a generic APR::Table which is tested in
    # apr/table.t.

    # object test
    $dir_config = $s->dir_config;
    ok defined $dir_config && ref($dir_config) eq 'APR::Table';

    # PerlAddVar ITERATE2 test
    {
        my $key = 'TestModperl__server_rec_Key_set_in_Base';
        my @received = $dir_config->get($key);
        my @expected = qw(1_SetValue 2_AddValue 3_AddValue);

        ok t_cmp(\@expected, \@received,
                 "testing PerlAddVar ITERATE2 in $s");
    }

    {
        # base server test
        my $bs = Apache->server;
        ok t_cmp('Apache::Server',
                 ($bs && ref($bs)),
                 "base server's object retrieval");

        my $key = 'TestModperl__server_rec_Key_set_in_Base';
        ok t_cmp('1_SetValue',
                 scalar ($bs->dir_config->get($key)),
                 "read dir_config of the base server");
    }

    Apache::OK;
}

my $key_base = "TestModperl__request_rec_Key";
my $counter  = 0;

sub make_key {
    return $key_base .
        (defined $_[0]
            ? $_[0]
            : unpack "H*", pack "n", ++$counter . rand(100));
}
1;
__END__
<Base>
    PerlSetVar TestModperl__request_rec_Key_set_in_Base BaseValue

    PerlSetVar TestModperl__server_rec_Key_set_in_Base 1_SetValue
    PerlAddVar TestModperl__server_rec_Key_set_in_Base 2_AddValue 3_AddValue
</Base>

PerlSetVar TestModperl__request_rec_Key0 SetValue0

PerlSetVar TestModperl__request_rec_Key1 ToBeLost
PerlSetVar TestModperl__request_rec_Key1 1_SetValue
PerlAddVar TestModperl__request_rec_Key1 2_AddValue
PerlAddVar TestModperl__request_rec_Key1 3_AddValue 4_AddValue

PerlSetVar TestModperl__server_rec_Key_set_in_Base WhatEver
