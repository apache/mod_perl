package TestAPI::response;

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::Response ();

use Apache::Test;

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 6;

    ok $r->make_etag(0);

    $r->set_content_length(0);

    ok 1;

    ok $r->meets_conditions || 1;

    ok $r->rationalize_mtime(time) >= $r->request_time;

    my $mtime = (stat __FILE__)[9];

    $r->update_mtime($mtime);

    ok $r->mtime == $mtime;

    $r->set_last_modified;

    $r->custom_response(500, "xxx");

    ok 1;

    Apache::OK;
}

1;
