use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

use constant INTERP => 'X-PerlInterpreter';

plan tests => 3, \&have_lwp;

my $url = "/TestModperl::interp";

#request an interpreter instance
my $res = GET $url, INTERP, 'init';

#use this interpreter id to select the same interpreter in requests below
my $interp = $res->header(INTERP);

print "using interp: $interp\n";

print $res->content;

my $found_interp = "";
my $find_interp = sub {
    $res->code == 200 and (($found_interp = $res->header(INTERP)) eq $interp);
};

for (1..2) {
    my $times = 0;

    do {
        #loop until we get a response from our interpreter instance
        $res = GET $url, INTERP, $interp;

        #trace info
        unless ($find_interp->()) {
            print $found_interp ?
              "wrong interpreter: $found_interp\n" :
              "no interpreter\n";
        }

        if ($times++ > 15) { #prevent endless loop
            die "unable to find interp $interp\n";
        }
    } while (not $find_interp->());

    print $res->content; #ok $value++
}

