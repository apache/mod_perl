#!perl

use strict;
use warnings FATAL => 'all';

use lib map { "$_/Apache-Test/lib" } qw(. ..);

use Apache::TestRunPerl ();

Apache::TestRunPerl->new->run(@ARGV);
