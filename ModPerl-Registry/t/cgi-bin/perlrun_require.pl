#!/usr/bin/perl

use Apache::Test ();
use File::Spec::Functions qw(catfile);

my $vars = Apache::Test::config()->{vars};
my $require = catfile $vars->{serverroot}, 'cgi-bin', 'lib.pl';

require $require;

print "Content-type: text/plain\n\n";

print whatever();


