package TestModules::cgiupload2;

# this handler doesn't use the :Apache layer, so CGI.pm needs to do
# $r->read(...)  instead of read(STDIN,...)

use strict;
use warnings FATAL => 'all';

use Apache::compat ();
use CGI ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    my $cgi = CGI->new($r);

    local $\;
    local $/;
    my $file = $cgi->param('filename');
    $r->print(<$file>);

    Apache::OK;
}

1;
