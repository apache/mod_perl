package TestModules::cgi2;

# this handler doesn't use the :Apache layer, so CGI.pm needs to do
# $r->read(...)  instead of read(STDIN,...)

use strict;
use warnings FATAL => 'all';

use Apache::compat ();
use CGI ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    unless ($ENV{MOD_PERL}) {
        die "\$ENV{MOD_PERL} is not set";
    }

    if ($CGI::Q) {
        die "CGI.pm globals were not reset";
    }

    unless ($CGI::MOD_PERL) {
        die "CGI.pm does not think this is mod_perl";
    }

    my $cgi = CGI->new($r);

    my $param = $cgi->param('PARAM');
    my $httpupload = $cgi->param('HTTPUPLOAD');

    $r->print($cgi->header('-type' => 'text/test-output',
                           '-X-Perl-Module' => __PACKAGE__));

    if ($httpupload) {
        no strict;
        local $/;
        my $content = <$httpupload>;
        $r->print("ok $content");
    }
    elsif ($param) {
        $r->print("ok $param");
    }
    else {
        $r->print("no param or upload data\n");
    }

    Apache::OK;
}

1;

