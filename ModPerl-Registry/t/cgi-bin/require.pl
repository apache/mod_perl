# test the require

print "Content-type: text/plain\r\n\r\n";

use lib qw(.);
my $file = "./local-conf.pl";
require $file;

print defined $test_require && $test_require;
