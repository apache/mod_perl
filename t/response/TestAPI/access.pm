package TestAPI::access;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use Apache::Access ();

use Apache::Const -compile => qw(OK :options :override :satisfy);

sub handler {
    my $r = shift;

    plan $r, tests => 10;

    $r->allow_methods(1, qw(GET POST));

    ok 1;

    ok $r->allow_options & Apache::OPT_INDEXES;

    ok !($r->allow_options & Apache::OPT_EXECCGI);

    ok !($r->allow_overrides & Apache::OR_LIMIT);

    ok $r->satisfies == Apache::SATISFY_NOSPEC;

    ok $r->auth_name eq 'modperl';

    $r->auth_name('modperl_test');
    ok $r->auth_name eq 'modperl_test';
    $r->auth_name('modperl');

    ok $r->auth_type eq 'none';
    
    $r->auth_type('Basic');
    ok $r->auth_type eq 'Basic';
    $r->auth_type('none');

    ok !$r->some_auth_required;

    Apache::OK;
}

1;
__END__
Options None
Options Indexes FollowSymLinks
AuthName modperl
AuthType none
