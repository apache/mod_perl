package TestModules::cgi;

use strict;
use warnings FATAL => 'all';

use Apache::compat ();
use CGI ();

sub handler {
    my $r = shift;

    my $cgi = CGI->new;

    my $param = $cgi->param('PARAM');
    my $httpupload = $cgi->param('HTTPUPLOAD');

    print $cgi->header('-type' => 'text/plain',
                       '-X-Perl-Script' => 'cgi.pm');
    $r->send_cgi_header("X-Foo-Bar: baz\r\n\r\nthis is text\n");
    print "ok $param\n" if $param;

    if ($httpupload) {
        no strict;
        local $/;
        my $content = <$httpupload>;
        print "ok $content\n";
    }

    Apache::OK;
}

1;
__END__
SetHandler perl-script
PerlOptions +GlobalRequest
