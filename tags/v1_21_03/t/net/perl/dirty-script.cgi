local $^W = 0;
use lib '.';
require "dirty-lib";
unless (defined(&not_ina_package) && not_ina_package()) {
    die "%INC save/restore broken";
}

print "Content-type: text/plain\n\n";

open FH, $0 or die $!;

sub subroutine {}
*imported = \&Outside::imported;

push @array, 1;

$scalar++;

$hash{key}++;

print __PACKAGE__, " is dirty";

exit;

__END__
