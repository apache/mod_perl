use lib '.';
require "dirty-lib";
unless (defined(&not_ina_package) && not_ina_package()) {
    die "%INC save/restore broken";
}

package Apache::ROOT::dirty_2dperl::dirty_2dscript_2epl;

use Apache::test;

print "Content-type: text/plain\n\n";

print "1..6\n";

my $i = 0;

test ++$i, not defined &subroutine;
test ++$i, not defined @array;
test ++$i, not defined %hash;
test ++$i, not defined $scalar;
test ++$i, not defined fileno(FH);
test ++$i, Outside::imported() == 4;


