#need apply patches/c-scan.pat against C-Scan-0.74

BEGIN {
    #rather than use lib cos were gonna fork
    $ENV{PERL5LIB} = "lib";
}

use strict;
use Apache::ParseSource ();

my $p = Apache::ParseSource->new;

$p->parse;

$p->write_functions_pm;

$p->write_structs_pm;
