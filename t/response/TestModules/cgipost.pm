package TestModules::cgipost;

use strict;
use warnings FATAL => 'all';

use Apache::compat ();
use CGI ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    $r->content_type('text/plain');
    my $cgi = CGI->new;

    print join ":", map { $cgi->param($_) } $cgi->param;

    Apache::OK;
}

1;
__END__
SetHandler perl-script
PerlOptions +GlobalRequest
