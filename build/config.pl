#!/usr/bin/perl -w

use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use ModPerl::Config ();

print ModPerl::Config::config_as_str();
