package TestFilter::buckets;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::Filter ();
use APR::Brigade ();
use APR::Bucket ();

use Apache::Const -compile => 'OK';

sub handler {
    my($filter, $bb) = @_;

    Apache::TestToString->start;

    plan tests => 4;

    my $ba = $filter->r->connection->bucket_alloc;

    #should only have 1 bucket from the response() below
    for (my $bucket = $bb->first; $bucket; $bucket = $bb->next($bucket)) {
        ok $bucket->type->name;
        ok $bucket->length == 2;
        $bucket->read(my $data);
        ok $data eq 'ok';
    }

    my $tests = Apache::TestToString->finish;

    my $brigade = APR::Brigade->new($filter->r->pool, $ba);
    my $bucket = APR::Bucket->new($tests);

    $brigade->insert_tail($bucket);

    my $ok = $brigade->first->type->name =~ /mod_perl/ ? 4 : 0;
    $brigade->insert_tail(APR::Bucket->new("ok $ok\n"));

    $filter->next->pass_brigade($brigade);

    Apache::OK;
}

sub response {
    my $r = shift;

    $r->content_type('text/plain');
    $r->puts("ok");

    0;
}

1;
__DATA__
SetHandler modperl
PerlResponseHandler TestFilter::buckets::response
