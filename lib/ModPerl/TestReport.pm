# Copyright 2003-2005 The Apache Software Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
package ModPerl::TestReport;

use strict;
use warnings FATAL => 'all';

use base qw(Apache::TestReportPerl);

my @interesting_packages = qw(
    CGI
    ExtUtils::MakeMaker
    Apache2::Request
    mod_perl2
    LWP
    Apache2
    mod_perl
);

# we want to see only already installed packages, so skip over
# modules that are about to be installed
my @skip_dirs = qw(
    blib/lib
    blib/lib/Apache2
    blib/arch
    blib/arch/Apache2
    lib
);
my $skip_dir_str = join '|', map { s|/|[/\\\\]|g; $_ } @skip_dirs;
my $skip_dir_pat = qr|[/\\]($skip_dir_str)[/\\]*$|;

sub packages {

    # search in Apache2/ subdirs too
    eval { require Apache2 };
    my @inc = grep !/$skip_dir_pat/, @INC;

    my %packages = ();
    my $max_len = 0;
    for my $package (sort @interesting_packages ) {
        $max_len = length $package if length $package > $max_len;
        my $filename = package2filename($package);
        my @ver = ();
        for my $dir (@inc) {
            my $path = "$dir/$filename";
            if (-e $path) {
                no warnings 'redefine';
                my $ver = eval { require $path;
                                 delete $INC{$path};
                                 $package->VERSION;
                         };
                # two versions could be installed (one under Apache2/)
                push @{ $packages{$package} }, $ver if $ver;
            }
        }
    }

    my @lines = "*** Packages of interest status:\n";

    for my $package (sort @interesting_packages) {
        my $vers = exists $packages{$package} 
            ? join ", ", sort @{ $packages{$package} }
            : "-";
        push @lines, sprintf "%-${max_len}s: %s", $package, $vers;
    }

    return join "\n", @lines, '';
}

sub config {
    my $self = shift;

    my @report = ();

    # core config
    push @report, ModPerl::Config::as_string();

    # installed packages
    push @report, $self->packages;

    # this report is generated by user/group

    return join "\n", @report;
}

sub package2filename {
    my $package = shift;
    $package =~ s|::|/|g;
    $package .= ".pm";
    return $package;
}

sub report_to { 'modperl@perl.apache.org' }


1;
