#!perl

use strict;
use warnings FATAL => 'all';

use lib map { "$_/Apache-Test/lib" } qw(. ..);

use Apache::TestRun ();

Apache::TestRun->new->run(@ARGV);
