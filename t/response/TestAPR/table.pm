package TestAPR::table;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use Apache::Const -compile => 'OK';
use APR::Table ();

sub handler {
    my $r = shift;

    plan $r, tests => 5;

    my $table = APR::Table::make($r->pool, 16);

    ok (UNIVERSAL::isa($table, 'APR::Table'));

    ok $table->set('foo','bar') || 1;

    ok $table->get('foo') eq 'bar';

    ok $table->unset('foo') || 1;

    ok not defined $table->get('foo');

    Apache::OK;
}

1;
