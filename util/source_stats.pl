#!/usr/bin/perl -w

use lib qw(lib);

use strict;
use Apache2::FunctionTable ();
use Apache2::StructureTable ();

my %stats;

for my $entry (@$Apache2::FunctionTable) {
    unless ($entry->{name} =~ /^(ap|apr)_/) {
        #print "found alien function $entry->{name}\n";
        next;
    }

    $stats{functions}->{$1}++;
}

for my $entry (@$Apache2::StructureTable) {
    my $elts = $entry->{elts};
    my $type = $entry->{type};

    my $c = $type =~ /^apr_/ ? "apr" : "ap";
    @$elts = () if $type =~ /^ap_LINK/;
    if (@$elts) {
        $stats{typedef_structs}->{$c}++;
        $stats{struct_members}->{$c} += @$elts;
    }
    else {
        $stats{typedefs}->{$c}++;
    }
}

while (my($name, $tab) = each %stats) {
    printf "%d %s\n", $tab->{ap} + $tab->{apr}, $name;
    for (qw(apr ap)) {
        printf "%6s: %d\n", $_, $tab->{$_};
    }
}
