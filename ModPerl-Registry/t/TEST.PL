#!perl

use strict;
use warnings FATAL => 'all';

# XXX: fixme
#use lib map { "$_/Apache-Test/lib" } qw(. ..);
#use lib map { "$_/blib/lib"        } qw(. .. ../..);
#use lib map { "$_/lib"             } qw(. .. ../..);
#use blib map { $_ } qw(. .. ../..);

use lib map {("../blib/$_", "../../blib/$_")} qw(lib arch);
#use blib qw(..);

use Apache::TestRunPerl ();

Apache::TestRunPerl->new->run(@ARGV);
