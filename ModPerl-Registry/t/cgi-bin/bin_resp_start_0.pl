#!/usr/bin/perl -w

use strict;
use warnings FATAL => 'all';

# favicon.ico and other .ico image/x-icon images start with this sequence
my $response = "\000\000\001\000";

# test here that the cgi header parser doesn't get confused and decide
# that there is no response body if it starts with \000 sequence

print "Content-type: image/x-icon\n\n";
print $response;
