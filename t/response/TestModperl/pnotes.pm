package TestModperl::pnotes;

use strict;
use warnings FATAL => 'all';

use Apache::RequestUtil ();

use Apache::Test;
use Apache::TestUtil;

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 5;

    ok $r->pnotes;

    ok t_cmp('pnotes_bar',
             $r->pnotes('pnotes_foo', 'pnotes_bar'),
             q{$r->pnotes(key,val)});

    ok t_cmp('pnotes_bar',
             $r->pnotes('pnotes_foo'),
             q{$r->pnotes(key)});

    ok t_cmp('HASH', ref($r->pnotes), q{ref($r->pnotes)});

    ok t_cmp('pnotes_bar', $r->pnotes()->{'pnotes_foo'},
             q{$r->pnotes()->{}});

    Apache::OK;
}

1;
__END__


