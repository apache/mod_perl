package TestModperl::current_callback;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use ModPerl::Util;

use APR::Table ();
use Apache::RequestRec ();

use Apache::Const -compile => qw(OK DECLINED);

sub handler {
    my $r = shift;

    plan $r, tests => 1;
    my $callback = ModPerl::Util::current_callback();
    ok t_cmp($callback,
             'PerlResponseHandler',
             'inside PerlResponseHandler');

    #warn "in callback: $callback\n";

    Apache::OK;
}

sub log          { check('Log')          }
sub fixup        { check('Fixup')        }
sub headerparser { check('HeaderParser') }

sub check {
    my $expected = 'Perl' . shift() . 'Handler';
    my $callback = ModPerl::Util::current_callback();
    die "expecting $expected callback, instead got $callback" 
        unless $callback eq $expected;
    #warn "in callback: $callback\n";
    return Apache::OK;
}

1;
__DATA__
PerlModule              TestModperl::current_callback
PerlHeaderParserHandler TestModperl::current_callback::headerparser
PerlFixupHandler        TestModperl::current_callback::fixup
PerlResponseHandler     TestModperl::current_callback
PerlLogHandler          TestModperl::current_callback::log
SetHandler modperl
