#!/usr/bin/perl -w

use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use ModPerl::Config ();

my $env = ModPerl::Config::as_string();
{
    local $/ = undef;
    my $template = <DATA>;
    $template =~ s/\[CONFIG\]/$env/;
    print $template;
}

__DATA__

-------------8<----------Start Bug Report ------------8<----------
1. Problem Description:

  [DESCRIBE THE PROBLEM HERE]

2. Used Components and their Configuration:

[CONFIG]

3. This is the core dump trace: (if you get a core dump):

  [CORE TRACE COMES HERE]

-------------8<----------End Bug Report --------------8<----------

Note: Complete the rest of the details and post this bug report to
dev@perl.apache.org as is. To subscribe to the list send an empty
email to dev-subscribe@perl.apache.org.
