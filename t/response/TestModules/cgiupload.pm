package TestModules::cgiupload;

use strict;
use warnings FATAL => 'all';

use Apache::compat ();
use CGI ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    my $cgi = CGI->new;

    my $file = $cgi->param('filename');

    while (<$file>) {
        print;
    }

    Apache::OK;
}

1;
__END__
SetHandler perl-script
PerlOptions +GlobalRequest
