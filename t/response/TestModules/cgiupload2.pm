package TestModules::cgiupload2;

# this handler doesn't use the :Apache layer, so CGI.pm needs to do
# $r->read(...)  instead of read(STDIN,...)

use strict;
use warnings FATAL => 'all';

use Apache2::compat ();
use CGI ();

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    my $cgi = CGI->new($r);

    local $\;
    local $/;
    my $file = $cgi->param('filename');
    $r->print(<$file>);

    Apache2::OK;
}

1;
