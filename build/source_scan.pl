#requires C::Scan 0.75+

use lib qw(lib);

use strict;
use Apache::ParseSource ();
use ModPerl::ParseSource ();
use ModPerl::FunctionMap ();

my $p = Apache::ParseSource->new(prefixes => ModPerl::FunctionMap->prefixes,
                                 @ARGV);

$p->parse;

$p->write_functions_pm;

$p->write_structs_pm;

$p = ModPerl::ParseSource->new(@ARGV);

$p->parse;

$p->write_functions_pm;
