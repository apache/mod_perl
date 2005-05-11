#!perl -w

# test that prefork runs from the directory the script lives in

# All Modperl::*Prefork modules must chdir into the current dir, so we
# should be able to read ourselves via a relative path

print "Content-type: text/plain\n\n";

my $script = "prefork.pl";
if (open my $fh, $script) {
    print "ok $script";
}
else {
    print "prefork didn't chdir into the scripts directory?";
    print " The error was: $!";
}


