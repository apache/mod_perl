#!perl -w

# this script will suffer from a closure problem under registry
# should see it under ::Registry
# should not see it under ::PerlRun

print "Content-type: text/plain\r\n\r\n";

# this is a closure (when compiled inside handler()):
my $counter = 0;
counter();

sub counter {
    #warn "$$";
    print ++$counter;
}

