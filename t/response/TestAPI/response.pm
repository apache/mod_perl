package TestAPI::response;

# testing Apache::Response methods
#
# XXX: a proper test is needed (at the moment just test that methods
# can be invoked as documented)

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::Response ();

use Apache::Test;
use Apache::TestUtil;

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 7;

    my $etag = $r->make_etag();
    t_debug $etag;
    ok $etag;

    $r->set_content_length(0);

    ok 1;

    ok $r->meets_conditions || 1;

    ok $r->rationalize_mtime(time) >= $r->request_time;

    my $mtime = (stat __FILE__)[9];

    $r->update_mtime($mtime);

    ok $r->mtime == $mtime;

    ok $r->set_keepalive() || 1;

    $r->set_last_modified;

    # $r->custom_response() is tested in TestAPI::custom_response

    ok 1;

    Apache::OK;
}

1;
