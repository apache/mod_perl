use strict;
use Apache::test;
my $i = 0;
my $r = shift;
$r->send_http_header("text/plain");

eval {
    require Apache::Log;
};
if($@) {
    print "$@\n";
    print "1..0\n";
    return;
}

my $rlog = $r->log;
my $slog = $r->server->log;
my @methods = qw{
emergency
alert
critical
error
warn
notice
info
debug
};
my $tests = @methods * 2;
print "1..$tests\n";
for my $method (@methods)
{
    if(defined $ENV{USER} and $ENV{USER} eq "dougm") {
	$rlog->$method("Apache->method $method ", "OK");
	$slog->$method("Apache::Server->method $method ", "OK");
    }
    print "method $method OK\n";
    test ++$i, $rlog->can($method);
    test ++$i, $slog->can($method);
}

