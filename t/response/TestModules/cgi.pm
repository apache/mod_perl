package TestModules::cgi;

use strict;
use warnings FATAL => 'all';

use Apache::compat ();
use CGI ();

sub handler {
    my $r = shift;

    system "echo hi";

    if ($CGI::Q) {
        die "CGI.pm globals were not reset";
    }

    unless ($CGI::MOD_PERL) {
        die "CGI.pm does not think this is mod_perl";
    }

    my $cgi = CGI->new;

    my $param = $cgi->param('PARAM');
    my $httpupload = $cgi->param('HTTPUPLOAD');

    print $cgi->header('-type' => 'text/test-output',
                       '-X-Perl-Module' => __PACKAGE__);

    if ($httpupload) {
        no strict;
        local $/;
        my $content = <$httpupload>;
        print "ok $content\n";
    }
    elsif ($param) {
        print "ok $param\n";
    }
    else {
        print "no param or upload data\n";
    }

    Apache::OK;
}

1;
__END__
SetHandler perl-script
PerlOptions +GlobalRequest
