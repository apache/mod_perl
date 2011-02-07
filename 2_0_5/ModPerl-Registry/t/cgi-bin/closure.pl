#!perl -w

BEGIN {
    use Apache::TestUtil;
    t_server_log_warn_is_expected();
}

# this script will suffer from a closure problem under registry
# should see it under ::Registry
# should not see it under ::PerlRun

print "Content-type: text/plain\n\n";

# this is a closure (when compiled inside handler()):
my $counter = 0;
counter();

sub counter {
    #warn "$$";
    print ++$counter;
}

