package TestAPI::server_rec;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::ServerUtil ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    my $s = $r->server;

    plan $r, tests => 21;

    ok $s;

    ok $s->process;

    ok $s->next || 1;

    ok $s->server_admin;

    ok $s->server_hostname;

    ok $s->port || 1;

    ok $s->error_fname || 1; #vhost might not have its own (t/TEST -ssl)

    #error_log;

    ok $s->loglevel;

    ok $s->is_virtual || 1;

    #module_config

    #lookup_defaults

    ok $s->addrs;

    ok $s->timeout;

    #keep_alive_timeout
    #keep_alive_max
    #keep_alive

    ok $s->path || 1;

    ok $s->names || 1;

    ok $s->wild_names || 1;

    ok $s->limit_req_line;

    ok $s->limit_req_fieldsize;

    ok $s->limit_req_fields;

    
    #<- dir_config tests ->#

    # this test doesn't test all $s->dir_config->*(), since
    # dir_config() returns a generic APR::Table which is tested in
    # apr/table.t.

    # object test
    my $dir_config = $s->dir_config;
    ok defined $dir_config && ref($dir_config) eq 'APR::Table';

    # PerlAddVar ITERATE2 test
    {
        my $key = 'TestAPI__server_rec_Key_set_in_Base';
        my @received = $dir_config->get($key);
        my @expected = qw(1_SetValue 2_AddValue 3_AddValue);
        ok t_cmp(
                 \@expected,
                 \@received,
                 "testing PerlAddVar ITERATE2 in $s",
                )
    }

    {
        # base server test
        my $bs = Apache->server;
        ok t_cmp(
               'Apache::Server',
               ($bs && ref($bs)),
               "base server's object retrieval"
              );

        my $key = 'TestAPI__server_rec_Key_set_in_Base';
        ok t_cmp(
               '1_SetValue',
               scalar ($bs->dir_config->get($key)),
               "read dir_config of the base server"
              );
    }

    Apache::OK;

}

1;

__END__
<Base>
    PerlSetVar TestAPI__server_rec_Key_set_in_Base 1_SetValue
    PerlAddVar TestAPI__server_rec_Key_set_in_Base 2_AddValue 3_AddValue
</Base>
PerlSetVar TestAPI__server_rec_Key_set_in_Base WhatEver

