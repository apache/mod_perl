
use Apache::test;

my $r = shift;
$r->send_http_header('text/plain');

unless(have_module "Apache::File") {
    print "1..0\n";
    return;
}

require Apache::File;
print "1..5\n";
my $fh = Apache::File->new;
test ++$i, $fh;
test ++$i, $fh->open($0);
test ++$i, !$fh->open("$0.nochance");
test ++$i, !Apache::File->new("$0.yeahright");
#my $tmp = Apache::File->tmp;
#test ++$i, $tmp;
#++$i;
#print $tmp "ok $i\n";
#seek $tmp, 0, 0;
#print scalar(<$tmp>);
test ++$i, Apache::File->tmpfile;
