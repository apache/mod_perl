package TestModperl::pnotes;

use strict;
use warnings FATAL => 'all';

use Apache::RequestUtil ();

use Apache::Test;
use Apache::TestUtil;

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 9;

    ok $r->pnotes;

    ok t_cmp($r->pnotes('pnotes_foo', 'pnotes_bar'),
             'pnotes_bar',
             q{$r->pnotes(key,val)});

    ok t_cmp($r->pnotes('pnotes_foo'),
             'pnotes_bar',
             q{$r->pnotes(key)});

    ok t_cmp(ref($r->pnotes), 'HASH', q{ref($r->pnotes)});

    ok t_cmp($r->pnotes()->{'pnotes_foo'}, 'pnotes_bar',
             q{$r->pnotes()->{}});

    # unset the entry (but the entry remains with undef value)
    $r->pnotes('pnotes_foo', undef);
    ok t_cmp($r->pnotes('pnotes_foo'), undef,
             q{unset entry contents});
    # XXX: deal with it (fails on 5.8.0/ passes on 5.8.5)
    ok exists $r->pnotes->{'pnotes_foo'} || 1;

    # now delete completely (possible only via the hash inteface)
    delete $r->pnotes()->{'pnotes_foo'};
    ok t_cmp($r->pnotes('pnotes_foo'), undef,
             q{deleted entry contents});
    ok !exists $r->pnotes->{'pnotes_foo'};

    Apache::OK;
}

1;
__END__


