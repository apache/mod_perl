package TestApache::scanhdrs;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use Apache2::compat ();

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    print "Status: 200 Bottles of beer on the wall\n";
    print 'X-Perl-Module', ': ', __PACKAGE__;
    print "\r\n";
    print "Content-type: text/test-";
    print "output\n";
    print "\n";

    print "ok 1\n";

    Apache2::OK;
}

1;
__END__
SetHandler perl-script
PerlOptions +ParseHeaders
