use strict;
use warnings;

my $r = shift;
$r->content_type('text/plain');
print "Oops, can't find the requested doc";
