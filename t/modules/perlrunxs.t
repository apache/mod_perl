use Apache::test;

skip_test if $] >= 5.005; #will fix later
skip_test unless $net::callback_hooks{PERL_RUN_XS};

#print fetch "/perl_xs/api.pl";

$ENV{PERL_DIR} = "/perl_xs";

my $dir = "";
for (qw(.. .)) {
    $dir = $_;
    last if -d "$dir/internal";
}

my $i = 0;
my @internal = map { "$dir/internal/$_" } 
qw(api.t http-get.t http-post.t table.t);
my $tests = @internal;
print "1..$tests\n";

for (@internal) {
    my($max, $failed) = run_test($_, 1);
    test ++$i, not @$failed;
    if(@$failed) {
	print "Test $_ failed tests ", join(", ", @$failed), "\n";
    }
}

