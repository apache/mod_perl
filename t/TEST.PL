#!perl

use strict;
use warnings FATAL => 'all';
use Config;

use lib map { "$_/Apache-Test/lib" } qw(. ..);

use Apache::TestRunPerl ();

$^X = $Config{perlpath} if $^X eq 'perl';

Apache::TestRunPerl->new->run(@ARGV);
