package TestHooks::stacked_handlers;

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();

use Apache::Const -compile => qw(OK DECLINED);

sub handler {
    my $r = shift;

    $r->handler("modperl");
    $r->push_handlers(PerlResponseHandler => [\&one, \&two, \&three, \&four]);

    return Apache::OK;
}

sub one {
    my $r = shift;

    $r->content_type('text/plain');
    $r->print("one\n");

    return Apache::OK;
}

sub two {
    my $r = shift;

    $r->print("two\n");

    return Apache::OK;
}

sub three {
    my $r = shift;

    $r->print("three\n");

    return Apache::DONE;
}

# this one shouldn't get called, because the three has returned DONE
sub four {
    my $r = shift;

    $r->print("four\n");

    return Apache::OK;
}


1;
__DATA__
<NoAutoConfig>
  <Location /TestHooks::stacked_handlers>
      SetHandler modperl
      PerlHeaderParserHandler TestHooks::stacked_handlers
  </Location>
</NoAutoConfig>

