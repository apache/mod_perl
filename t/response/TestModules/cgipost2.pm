package TestModules::cgipost2;

# this handler doesn't use the :Apache layer, so CGI.pm needs to do
# $r->read(...)  instead of read(STDIN,...)

use strict;
use warnings FATAL => 'all';

use Apache::compat ();
use CGI ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    $r->content_type('text/plain');
    my $cgi = CGI->new($r);

    $r->print(join ":", map { $cgi->param($_) } $cgi->param);

    Apache::OK;
}

1;
__END__

