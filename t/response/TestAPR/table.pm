package TestAPR::table;

# testing APR::Table API

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use APR::Table ();

use Apache::Const -compile => 'OK';
use APR::Const    -compile => ':table';

use constant TABLE_SIZE => 20;
my $filter_count;

sub handler {
    my $r = shift;

    my $tests = 38;

    plan $r, tests => $tests;

    my $table = APR::Table::make($r->pool, TABLE_SIZE);

    ok UNIVERSAL::isa($table, 'APR::Table');

    # get on non-existing key
    {
        # in scalar context
        my $val = $table->get('foo');
        ok t_cmp(undef, $val, '$val = $table->get("no_such_key")');

        # in list context
        my @val = $table->get('foo');
        ok t_cmp(0, +@val, '@val = $table->get("no_such_key")');
    }

    # set/add/get/copy normal values
    {
        $table->set(foo => 'bar');

        # get scalar context
        my $val = $table->get('foo');
        ok t_cmp('bar', $val, '$val = $table->get("foo")');

        # add + get list context
        $table->add(foo => 'tar');
        $table->add(foo => 'kar');
        my @val = $table->get('foo');
        ok @val == 3         &&
            $val[0] eq 'bar' &&
            $val[1] eq 'tar' &&
            $val[2] eq 'kar';

        # copy
        $table->set(too => 'boo');
        my $table_copy = $table->copy($r->pool);
        my $val_copy = $table->get('too');
        ok t_cmp('boo', $val_copy, '$val = $table->get("too")');
        my @val_copy = $table_copy->get('foo');
        ok @val_copy == 3         &&
            $val_copy[0] eq 'bar' &&
            $val_copy[1] eq 'tar' &&
            $val_copy[2] eq 'kar';
    }

    # make sure 0 comes through as 0 and not undef
    {
        $table->set(foo => 0);
        my $zero = $table->get('foo');
        ok t_cmp(0, $zero, 'table value 0 is not undef');
    }

    # unset
    {
        $table->set(foo => "bar");
        $table->unset('foo');
        ok t_cmp(undef, +$table->get('foo'), '$table->unset("foo")');
    }

    # merge
    {
        $table->set(  merge => '1');
        $table->merge(merge => 'a');
        my $val = $table->get('merge');
        ok t_cmp("1, a", $val, 'one val $table->merge(...)');

        # if there is more than one value for the same key, merge does
        # the job only for the first value
        $table->add(  merge => '2');
        $table->merge(merge => 'b');
        my @val = $table->get('merge');
        ok t_cmp("1, a, b", $val[0], '$table->merge(...)');
        ok t_cmp("2",    $val[1], 'two values $table->merge(...)');

        # if the key is not found, works like set/add
        $table->merge(miss => 'a');
        my $val_miss = $table->get('miss');
        ok t_cmp("a", $val_miss, 'no value $table->merge(...)');
    }

    # clear
    {
        $table->set(foo => 0);
        $table->set(bar => 1);
        $table->clear();
        # t_cmp forces scalar context on get
        ok t_cmp(undef, $table->get('foo'), '$table->clear');
        ok t_cmp(undef, $table->get('bar'), '$table->clear');
    }

    # filtering
    {
        for (1..TABLE_SIZE) {
            $table->set(chr($_+97), $_);
        }

        # Simple filtering
        $filter_count = 0;
        $table->do("my_filter");
        ok t_cmp(TABLE_SIZE, $filter_count);

        # Filtering aborting in the middle
        $filter_count = 0;
        $table->do("my_filter_stop");
        ok t_cmp(int(TABLE_SIZE)/2, $filter_count) ;

        # Filtering with anon sub
        $filter_count=0;
        $table->do(sub {
            my ($key,$value) = @_;
            $filter_count++;
            unless ($key eq chr($value+97)) {
                die "arguments I recieved are bogus($key,$value)";
            }
            return 1;
        });

        ok t_cmp(TABLE_SIZE, $filter_count, "table size");

        $filter_count = 0;
        $table->do("my_filter", "c", "b", "e");
        ok t_cmp(3, $filter_count, "table size");
    }

    #Tied interface
    {
        my $table = APR::Table::make($r->pool, TABLE_SIZE);

        ok UNIVERSAL::isa($table, 'HASH');

        ok UNIVERSAL::isa($table, 'HASH') && tied(%$table);

        ok $table->{'foo'} = 'bar';

        # scalar context
        ok $table->{'foo'} eq 'bar';

        ok delete $table->{'foo'} || 1;

        ok not exists $table->{'foo'};

        for (1..TABLE_SIZE) {
            $table->{chr($_+97)} = $_;
        }

        $filter_count = 0;
        foreach my $key (sort keys %$table) {
            my_filter($key, $table->{$key});
        }
        ok $filter_count == TABLE_SIZE;
    }

    # overlap and compress routines
    {
        my $base = APR::Table::make($r->pool, TABLE_SIZE);
        my $add  = APR::Table::make($r->pool, TABLE_SIZE);

        $base->set(foo => 'one');
        $base->add(foo => 'two');

        $add->set(foo => 'three');
        $add->set(bar => 'beer');

        my $overlay = $base->overlay($add, $r->pool);

        my @foo = $overlay->get('foo');
        my @bar = $overlay->get('bar');

        ok t_cmp(3, +@foo);
        ok t_cmp('beer', $bar[0]);

        my $overlay2 = $overlay->copy($r->pool);

        # compress/merge
        $overlay->compress(APR::OVERLAP_TABLES_MERGE);
        # $add first, then $base
        ok t_cmp($overlay->get('foo'),
                 'three, one, two',
                 "\$overlay->compress/merge");
        ok t_cmp($overlay->get('bar'),
                 'beer',
                 "\$overlay->compress/merge");

        # compress/set
        $overlay->compress(APR::OVERLAP_TABLES_SET);
        # $add first, then $base
        ok t_cmp($overlay2->get('foo'),
                 'three',
                 "\$overlay->compress/set");
        ok t_cmp($overlay2->get('bar'),
                 'beer',
                 "\$overlay->compress/set");
    }

    # overlap set
    {
        my $base = APR::Table::make($r->pool, TABLE_SIZE);
        my $add  = APR::Table::make($r->pool, TABLE_SIZE);

        $base->set(bar => 'beer');
        $base->set(foo => 'one');
        $base->add(foo => 'two');

        $add->set(foo => 'three');

        $base->overlap($add, APR::OVERLAP_TABLES_SET);

        my @foo = $base->get('foo');
        my @bar = $base->get('bar');

        ok t_cmp(1, +@foo, 'overlap/set');
        ok t_cmp('three', $foo[0]);
        ok t_cmp('beer', $bar[0]);
    }

    # overlap merge
    {
        my $base = APR::Table::make($r->pool, TABLE_SIZE);
        my $add  = APR::Table::make($r->pool, TABLE_SIZE);

        $base->set(foo => 'one');
        $base->add(foo => 'two');

        $add->set(foo => 'three');
        $add->set(bar => 'beer');

        $base->overlap($add, APR::OVERLAP_TABLES_MERGE);

        my @foo = $base->get('foo');
        my @bar = $base->get('bar');

        ok t_cmp(1, +@foo, 'overlap/set');
        ok t_cmp('one, two, three', $foo[0]);
        ok t_cmp('beer', $bar[0]);
    }

    Apache::OK;
}

sub my_filter {
    my($key, $value) = @_;
    $filter_count++;
    unless ($key eq chr($value+97)) {
        die "arguments I received are bogus($key,$value)";
    }
    return 1;
}

sub my_filter_stop {
    my($key, $value) = @_;
    $filter_count++;
    unless ($key eq chr($value+97)) {
        die "arguments I received are bogus($key,$value)";
    }
    return $filter_count == int(TABLE_SIZE)/2 ? 0 : 1;
}

1;
