use Apache::test;

skip_test if WIN32;

my $qs = "I_am_dying";
my $content = fetch "/perl/throw_error.pl?$qs";

my $i = 0;

print "1..1\n";

print $content;
test ++$i, $content =~ /$qs/;

