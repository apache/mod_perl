#requires C::Scan 0.75+

use lib qw(lib);

use strict;
use Apache::ParseSource ();

my $p = Apache::ParseSource->new;

$p->parse;

$p->write_functions_pm;

$p->write_structs_pm;
