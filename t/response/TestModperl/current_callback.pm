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
    my $callback = Apache::current_callback();
    ok t_cmp('PerlResponseHandler',
             $callback,
             'inside PerlResponseHandler');

    #warn "in callback: $callback\n";

    Apache::OK;
}

sub log          { check('Log')          }
sub fixup        { check('Fixup')        }
sub headerparser { check('HeaderParser') }

sub check {
    my $expected = 'Perl' . shift() . 'Handler';
    my $callback = Apache::current_callback();
    die "expecting $expected callback, instead got $callback" 
        unless $callback eq $expected;
    #warn "in callback: $callback\n";
}

1;
__DATA__
PerlHeaderParserHandler TestModperl::current_callback::headerparser
PerlFixupHandler        TestModperl::current_callback::fixup
PerlResponseHandler     TestModperl::current_callback
PerlLogHandler          TestModperl::current_callback::log
SetHandler modperl
