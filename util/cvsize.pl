#get an idea of how much space the XS interface will eat
#build/source_scan.pl must be run first
#see pod/modperl_sizeof.pod

use strict;
use Apache::FunctionTable ();
use Apache::StructureTable ();

use constant sizeofCV => 254;

my $size = 0;
my $subs = 0;

for my $entry (@$Apache::FunctionTable) {
    $size += sizeofCV + ((length($entry->{name}) + 1) * 2);
    $subs++;
}

for my $entry (@$Apache::StructureTable) {
    my $elts = $entry->{elts} || [];
    next unless @$elts;

    for my $e (@$elts) {
        $size += sizeofCV + ((length($e->{name}) + 1) * 2);
        $subs++;
    }
}

print "$subs subs, $size estimated bytes\n";
