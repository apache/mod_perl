package TestHooks::push_handlers_anon;

# in addition to other anon sub handler tests in push_handlers*, here
# we test an anon sub added at the server startup. in order not to mess
# with the rest of the test suite, we run it in its own vhost

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::ServerUtil ();
use APR::Pool ();

use Apache2::Const -compile => qw(OK DECLINED);

use Apache::Test;
use Apache::TestUtil;

sub add_note {
    my $r = shift;

    my $count = $r->notes->get("add_note") || 0;
    $count++;
    $r->notes->set("add_note", $count);
    Apache2::Const::DECLINED;
}

# PerlFixupHandlers added at the server startup should add 3 notes
sub handler {
    my $r = shift;

    plan $r, tests => 1;

    my $count = $r->notes->get("add_note") || 0;
    ok t_cmp $count, 3, "$count callbacks";

    Apache2::Const::OK;
}

1;
__DATA__
<NoAutoConfig>
# APACHE_TEST_CONFIG_ORDER 1000
<VirtualHost TestHooks::push_handlers_anon>
    PerlModule            TestHooks::push_handlers_anon
    <Perl >
    # want to push a handler for a vhost, via $s, but the only way to
    # get $s for vhost is to traverse the vhosts list
    use Apache::Test;
    use Apache::TestRequest;
    Apache::TestRequest::module('TestHooks::push_handlers_anon');
    my $hostport = Apache::TestRequest::hostport(Apache::Test::config());
    my ($host, $port) = split ':', $hostport;
    my $s = Apache2::ServerUtil->server;
    my $vs = $s->next;
    for (; $vs; $vs = $vs->next) {
        last if $port == $vs->port
    }
    $vs->push_handlers(PerlFixupHandler => 
                       sub { &TestHooks::push_handlers_anon::add_note });
    $vs->push_handlers(PerlFixupHandler => 
                       \&TestHooks::push_handlers_anon::add_note       );
    $vs->push_handlers(PerlFixupHandler =>
                      "TestHooks::push_handlers_anon::add_note"        );
    </Perl>

    <Location /TestHooks__push_handlers_anon>
        SetHandler modperl
        PerlResponseHandler TestHooks::push_handlers_anon
    </Location>
</VirtualHost>
</NoAutoConfig>
