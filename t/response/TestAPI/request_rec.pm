package TestAPI::request_rec;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 49;

    #Apache->request($r); #PerlOptions +GlobalRequest takes care
    my $gr = Apache->request;

    ok $$gr == $$r;

    my $newr = Apache::RequestRec->new($r->connection, $r->pool);
    Apache->request($newr);
    $gr = Apache->request;

    ok $$gr == $$newr;

    Apache->request($r);

    ok $r->pool->isa('APR::Pool');

    ok $r->connection->isa('Apache::Connection');

    ok $r->server->isa('Apache::Server');

    for (qw(next prev main)) {
        ok (! $r->$_()) || $r->$_()->isa('Apache::RequestRec');
    }

    ok $r->the_request || 1;

    ok $r->assbackwards || 1;

    ok $r->proxyreq || 1;

    ok $r->header_only || 1;

    ok $r->protocol =~ /http/i;

    ok $r->proto_num;

    ok $r->hostname || 1;

    ok $r->request_time;

    ok $r->status_line || 1;

    ok $r->status || 1;

    ok $r->method;

    ok $r->method_number || 1;

    ok $r->allowed || 1;

    #allowed_xmethods
    #allow_methods

    ok $r->bytes_sent || 1;

    ok $r->mtime || 1;

    ok $r->headers_in;

    ok $r->headers_out;

    ok $r->err_headers_out;

    ok $r->subprocess_env;

    ok $r->notes;

    ok $r->content_type;

    ok $r->handler;

    #content_encoding
    #content_language
    #content_languages

    #user

    #<- dir_config tests ->#

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
        ok t_cmp(
                 \@expected,
                 \@received,
                 "testing PerlAddVar ITERATE2",
                )
    }

    {
        my $key = make_key('0');

        # object interface test in a scalar context (for a single
        # PerlSetVar key)
        ok t_cmp("SetValue0",
                 $dir_config->get($key),
                 qq{\$dir_config->get("$key")});

        #  direct fetch test in a scalar context (for a single
        #  PerlSetVar)
        ok t_cmp("SetValue0",
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
                 qq{\$r->dir_config($key => $val)});
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

    #no_cache
    ok $r->no_cache || 1;

    {
        local $| = 0;
        ok 9  == $r->print("buffered\n");
        ok 0  == $r->print();
        local $| = 1;
        ok 13 == $r->print('n','o','t',' ','b','u','f','f','e','r','e','d',"\n");
    }

    #no_local_copy

    ok $r->unparsed_uri;

    ok $r->uri;

    ok $r->filename;

    ok t_cmp('/' . __PACKAGE__,
             $r->location,
             "location");

    my $mtime = (stat __FILE__)[9];
    $r->mtime($mtime);

    ok $r->mtime == $mtime;

    ok $r->path_info || 1;

    ok $r->args || 1;

    #finfo
    #parsed_uri

    #per_dir_config
    #request_config

    #output_filters
    #input_filers

    #eos_sent

    Apache::OK;
}

my $key_base = "TestAPI__request_rec_Key";
my $counter  = 0;
sub make_key{
    return $key_base .
        (defined $_[0]
            ? $_[0]
            : unpack "H*", pack "n", ++$counter . rand(100) );
}
1;
__END__
<Base>
    PerlSetVar TestAPI__request_rec_Key_set_in_Base BaseValue
</Base>
PerlOptions +GlobalRequest

PerlSetVar TestAPI__request_rec_Key0 SetValue0


PerlSetVar TestAPI__request_rec_Key1 ToBeLost
PerlSetVar TestAPI__request_rec_Key1 1_SetValue
PerlAddVar TestAPI__request_rec_Key1 2_AddValue
PerlAddVar TestAPI__request_rec_Key1 3_AddValue 4_AddValue

