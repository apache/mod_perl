package TestApache::cookie;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::Const -compile => 'OK';

use Apache::RequestRec ();
use Apache::RequestIO ();

sub access {
    my $r = shift;

    my($key, $val) = cookie($r);
    die "I shouldn't get the cookie" if $r->args eq 'env' && defined $val;
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
PerlOptions -SetupEnv
SetHandler modperl
PerlModule          TestApache::cookie
PerlResponseHandler TestApache::cookie
PerlAccessHandler   TestApache::cookie::access

