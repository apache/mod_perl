use Apache::IO ();
use Apache::test;

my $r = shift;
$r->send_http_header('text/plain');

print "1..4\n";
my $fh = Apache::IO->new;
test ++$i, $fh;
test ++$i, $fh->open($0);
test ++$i, !$fh->open("$0.nochance");
test ++$i, !Apache::IO->new("$0.yeahright");
