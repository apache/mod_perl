use Apache::test;

skip_test if WIN32;

my $qs = "This_is_not_a_real_error";
my $content = fetch "/perl/throw_error.pl?$qs";

my $i = 0;

print "1..1\n";

print $content;
test ++$i, $content =~ /$qs/;

