package TestApache::cookie2;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::Const -compile => 'OK';

use Apache::RequestRec ();
use Apache::RequestIO ();

sub access {
    my $r = shift;

    my($key, $val) = cookie($r);
    die "Can't get the cookie" unless defined $val;
    return Apache::OK;
}

sub handler {
    my $r = shift;
    my($key, $val) = cookie($r);
    $r->print($val) if defined $val;
    return Apache::OK;
}

sub cookie {
    my $r = shift;
    my $header = $r->headers_in->{Cookie} || '';
    my $env    = $ENV{HTTP_COOKIE} || $ENV{COOKIE} || ''; # from CGI::Cookie

    return split '=', $r->args eq 'header' ? $header : $env;
}

1;

__DATA__
SetHandler perl-script
PerlModule          TestApache::cookie2
PerlResponseHandler TestApache::cookie2
PerlAccessHandler   TestApache::cookie2::access
# XXX: the test fails if +SetupEnv is not explicitly set
# because of the timing differences (+SetupEnv sets the env during the
# header phase, without it perl-script sets it for the response phase)
PerlOptions +SetupEnv
