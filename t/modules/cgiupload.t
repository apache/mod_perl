use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 2, \&have_lwp;

my $location = "/TestModules::cgiupload";

my $filename;
my $pod = 'pod/perlfunc.pod';

for (@INC) {
    if (-e "$_/$pod") {
        $filename = "$_/$pod";
        last;
    }
}

$filename ||= '../pod/modperl_2.0.pod';

for (1,2) {
    my $str = UPLOAD_BODY $location, filename => $filename;

    ok -s $filename == length($str);
}
