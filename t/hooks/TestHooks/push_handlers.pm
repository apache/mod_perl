package TestHooks::push_handlers;

# test various ways to push handlers

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();

use Apache::Const -compile => qw(OK DECLINED DONE);

sub handler {
    my $r = shift;

    $r->handler("modperl");

    $r->push_handlers(PerlResponseHandler => \&coderef);
    $r->push_handlers(PerlResponseHandler => 
        \&TestHooks::push_handlers::full_coderef);

    $r->push_handlers(PerlResponseHandler =>
        [\&coderef1, \&coderef2, \&coderef3]);

# XXX: anon-handlers unsupported yet
#    $r->push_handlers(PerlResponseHandler =>
#        sub { return say(shift, "anonymous") });

#    $r->push_handlers(PerlResponseHandler =>
#        [sub { return say(shift, "anonymous1") },
#         \&coderef4,
#         sub { return say(shift, "anonymous3") },
#        ]);

    $r->push_handlers(PerlResponseHandler => \&end);

    return Apache::DECLINED;
}

sub end { return Apache::DONE }
sub say { shift->print(shift,"\n"); return Apache::OK }

sub conf {
    # this one is configured from httpd.conf
    my $r= shift;
    $r->content_type('text/plain');
    return say($r, "conf");
}

sub conf1        { return say(shift, "conf1")        }
sub conf2        { return say(shift, "conf2")        }
sub coderef      { return say(shift, "coderef")      }
sub coderef1     { return say(shift, "coderef1")     }
sub coderef2     { return say(shift, "coderef2")     }
sub coderef3     { return say(shift, "coderef3")     }
sub coderef4     { return say(shift, "coderef4")     }
sub full_coderef { return say(shift, "full_coderef") }

1;
__DATA__
<NoAutoConfig>
  <Location /TestHooks::push_handlers>
      SetHandler modperl
      PerlHeaderParserHandler TestHooks::push_handlers
      PerlResponseHandler     TestHooks::push_handlers::conf
      PerlResponseHandler     TestHooks::push_handlers::conf1 TestHooks::push_handlers::conf2
  </Location>
</NoAutoConfig>

