package TestAPR::threadmutex;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::Const -compile => 'OK';
use APR::Const -compile => qw(EBUSY SUCCESS);

sub handler {
    my $r = shift;

    plan $r, tests => 4, 'APR::ThreadMutex';

    require APR::ThreadMutex;

    my $mutex = APR::ThreadMutex->new($r->pool);

    ok $mutex;

    ok t_cmp($mutex->lock, APR::SUCCESS,
             'lock == APR::SUCCESS');

    ok t_cmp($mutex->trylock, APR::EBUSY,
             'trylock == APR::EBUSY');

    ok t_cmp($mutex->unlock, APR::SUCCESS,
             'unlock == APR::SUCCESS');

    Apache::OK;
}

1;
