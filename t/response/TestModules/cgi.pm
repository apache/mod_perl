package TestModules::cgi;

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

    my $gw = $ENV{GATEWAY_INTERFACE} || '';
    unless ($gw eq 'CGI-Perl/1.1') {
        die "\$ENV{GATEWAY_INTERFACE} is not properly set ($gw)";
    }

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
        print "ok $content";
    }
    elsif ($param) {
        print "ok $param";
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
