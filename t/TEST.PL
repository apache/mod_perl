#!perl

use strict;
use warnings FATAL => 'all';

use FindBin;
use lib "$FindBin::Bin/../Apache-Test/lib";

use Apache::TestRunPerl ();

Apache::TestRunPerl->new->run(@ARGV);
