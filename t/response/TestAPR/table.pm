package TestAPR::table;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use APR::Table ();

use Apache::Const -compile => 'OK';
use APR::Const -compile => 'OVERLAP_TABLES_MERGE';

my $filter_count;
my $TABLE_SIZE = 20;

use constant HAVE_APACHE_2_0_47 => have_min_apache_version('2.0.47');

sub handler {
    my $r = shift;

    my $tests = 19;
    $tests += 2 if HAVE_APACHE_2_0_47;
                                                                                                    
    plan $r, tests => $tests;

    my $table = APR::Table::make($r->pool, $TABLE_SIZE);

    ok (UNIVERSAL::isa($table, 'APR::Table'));

    ok $table->set('foo','bar') || 1;

    # scalar context
    ok $table->get('foo') eq 'bar';

    # add + list context
    $table->add(foo => 'tar');
    $table->add(foo => 'kar');
    my @array = $table->get('foo');
    ok @array == 3        &&
       $array[0] eq 'bar' &&
       $array[1] eq 'tar' &&
       $array[2] eq 'kar';

    ok $table->unset('foo') || 1;

    ok not defined $table->get('foo');

    for (1..$TABLE_SIZE) {
        $table->set(chr($_+97), $_);
    }

    #Simple filtering
    $filter_count = 0;
    $table->do("my_filter");
    ok $filter_count == $TABLE_SIZE;

    #Filtering aborting in the middle
    $filter_count = 0;
    $table->do("my_filter_stop");
    ok $filter_count == int($TABLE_SIZE)/2;

    #Filtering with anon sub
    $filter_count=0;
    $table->do(sub {
        my ($key,$value) = @_;
        $filter_count++;
        unless ($key eq chr($value+97)) {
            die "arguments I recieved are bogus($key,$value)";
        }
        return 1;
    });

    ok $filter_count == $TABLE_SIZE;

    $filter_count = 0;
    $table->do("my_filter", "c", "b", "e");
    ok $filter_count == 3;

    #Tied interface
    {
        my $table = APR::Table::make($r->pool, $TABLE_SIZE);

        ok (UNIVERSAL::isa($table, 'HASH'));

        ok (UNIVERSAL::isa($table, 'HASH')) && tied(%$table);

        ok $table->{'foo'} = 'bar';

        # scalar context
        ok $table->{'foo'} eq 'bar';

        ok delete $table->{'foo'} || 1;

        ok not exists $table->{'foo'};

        for (1..$TABLE_SIZE) {
            $table->{chr($_+97)} = $_;
        }

        $filter_count = 0;
        foreach my $key (sort keys %$table) {
            my_filter($key, $table->{$key});
        }
        ok $filter_count == $TABLE_SIZE;
    }

    # overlay and compress routines
    my $base = APR::Table::make($r->pool, $TABLE_SIZE);
    my $add = APR::Table::make($r->pool, $TABLE_SIZE);

    $base->set(foo => 'one');
    $base->add(foo => 'two');

    $add->add(foo => 'three');
    $add->add(bar => 'beer');

    my $overlay = $base->overlay($add, $r->pool);

    my @foo = $overlay->get('foo');
    my @bar = $overlay->get('bar');

    ok @foo == 3;
    ok $bar[0] eq 'beer';

    # BACK_COMPAT_MARKER: make back compat issues easy to find :)
    if (HAVE_APACHE_2_0_47) {
        $overlay->compress(APR::OVERLAP_TABLES_MERGE);

        # $add first, then $base
        ok $overlay->get('foo') eq 'three, one, two';
        ok $overlay->get('bar') eq 'beer';
    }

    Apache::OK;
}

sub my_filter {
    my ($key,$value) = @_;
    $filter_count++;
    unless ($key eq chr($value+97)) {
        die "arguments I received are bogus($key,$value)";
    }
    return 1;
}

sub my_filter_stop {
    my ($key,$value) = @_;
    $filter_count++;
    unless ($key eq chr($value+97)) {
        die "arguments I received are bogus($key,$value)";
    }
    return 0 if ($filter_count == int($TABLE_SIZE)/2);
    return 1;
}

1;
