# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

use CGI ();
use Apache::Constants;
use strict qw(vars);
my $q = CGI->new;
$q->print($q->header(-type => "text/plain"));

my $version = SERVER_VERSION; 

if($version =~ /1\.1\.\d/) {
    print "1..1\nok 1\n";
    print "skipping tests against $version\n";
    die "";
}

my(%SEEN, @export, $key, $val);
while(($key,$val) = each %Apache::Constants::EXPORT_TAGS) {
    #warn "importing tag $key\n";
    Apache::Constants->import(":$key");
    push @export, grep {!$SEEN{$_}++} @$val;
}

push @export, grep {!$SEEN{$_}++} @Apache::Constants::EXPORT;

my $tests = (1 + @export) - 4; 
print "1..$tests\n"; 
#$loaded = 1;
$q->print("ok 1\n");
my $ix = 2;

my($sym);

#skip some 1.3 stuff that 1.2 didn't have
my %skip = map { $_,1 } qw(DONE REMOTE_DOUBLE_REV);

for $sym (sort @export) {
    next if $skip{$sym} or $sym =~ /SERVER_.*VERSION/;
    my $val = &$sym;
    $q->print(defined $val ? "" : "not ", "ok $ix ($sym: $val)\n");
    $ix++;
}

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

