package TestApache::scanhdrs2;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    my $location = $r->args;

    print "Location: $location\n\n";

    Apache::OK;
}

1;
__END__
SetHandler perl-script
PerlOptions +ParseHeaders
