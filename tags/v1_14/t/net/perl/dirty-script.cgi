local $^W = 0;

print "Content-type: text/plain\n\n";

open FH, $0 or die $!;

sub subroutine {}

push @array, 1;

$scalar++;

$hash{key}++;

print __PACKAGE__, " is dirty";

exit;

__END__
