#!perl

use strict;
use warnings FATAL => 'all';

use FindBin;
use lib "$FindBin::Bin/../Apache-Test/lib";
use lib "$FindBin::Bin/../lib";

use Apache::TestSmoke ();

Apache::TestSmoke->new(@ARGV)->run;
