package perlrun_decl;

use warnings;
use strict;

use base qw(Exporter);
our @EXPORT = qw(decl_proto);

sub decl_proto ($;$) { my $x = shift; $x*"0"; }

1;
