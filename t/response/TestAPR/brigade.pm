package TestAPR::brigade;

# testing APR::Brigade in this tests.
# Other tests do that too:
# TestAPR::flatten : flatten()
# TestAPR::bucket  : is_empty(), first(), last()

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::RequestRec ();
use APR::Brigade ();

use Apache::Const -compile => 'OK';

sub handler {

    my $r = shift;

    plan $r, tests => 10;

    # basic + pool + destroy
    {
        my $bb = APR::Brigade->new($r->pool, $r->connection->bucket_alloc);

        t_debug('$bb is defined');
        ok defined $bb;

        t_debug('$bb ISA APR::Brigade object');
        ok $bb->isa('APR::Brigade');

        my $pool = $bb->pool;

        t_debug('$pool is defined');
        ok defined $pool;

        t_debug('$pool ISA APR::Pool object');
        ok $pool->isa('APR::Pool');

        t_debug("destroy");
        $bb->destroy;
        ok 1;
    }

    # concat / split / length / flatten
    {
        my $bb1 = APR::Brigade->new($r->pool, $r->connection->bucket_alloc);
        $bb1->insert_head(APR::Bucket->new("11"));
        $bb1->insert_tail(APR::Bucket->new("12"));

        my $bb2 = APR::Brigade->new($r->pool, $r->connection->bucket_alloc);
        $bb2->insert_head(APR::Bucket->new("21"));
        $bb2->insert_tail(APR::Bucket->new("22"));

        # concat
        $bb1->concat($bb2);
        # bb1: 11, 12, 21, 22
        ok t_cmp(8, $bb1->length, "total data length in bb");
        ok t_cmp("11122122", $bb1->flatten, "bb flatten");
        t_debug('$bb2 is empty');
        ok $bb2->is_empty;

        # split
        my $b = $bb1->first; # 11
        $b = $bb1->next($b); # 12
        my $bb3 = $bb1->split($b);
        # bb1: 11, bb3: 12, 21, 22
        ok t_cmp("11",     $bb1->flatten, "bb flatten");
        ok t_cmp("122122", $bb3->flatten, "bb flatten");
    }

    Apache::OK;
}

1;
