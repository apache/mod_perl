#!/usr/bin/perl -w

my $r = shift;

print "HTTP/1.0 250 Pretty OK\r\n";
print join("\n",
     'Content-type: text/text',
     'Pragma: no-cache',
     'Cache-control: must-revalidate, no-cache, no-store',
     'Expires: -1',
     "\n");

print "non-parsed headers body";
