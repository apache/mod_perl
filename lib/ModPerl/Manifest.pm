# Copyright 2002-2005 The Apache Software Foundation
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
package ModPerl::Manifest;

use strict;
use warnings FATAL => 'all';

use File::Basename;
use File::Find;
use Cwd ();
use Exporter ();

our @EXPORT_OK = qw(mkmanifest);

*import = \&Exporter::import;

#generate a MANIFEST based on CVS/Entries
#anything to be skipped goes after __DATA__ (MANIFEST.SKIP format)
#anything else to be added should go here:
my @add_files = qw{
    MANIFEST
    mod_perl.spec
    Apache-Test/META.yml
};

sub get_svn_files {
    my @files;

    my $cwd = Cwd::cwd();

    finddepth({ follow => 1, wanted => sub {
        return unless $_ eq 'entries';
        return unless $File::Find::dir =~ /\.svn$/;

        my $dir = dirname $File::Find::dir;
        $dir =~ s,^$cwd/?,,;

        open my $fh, $_ or die "open $_: $!";
        while (my $line = <$fh>) {
             if ($line =~ /name\s*=\s*"([^"]*)"/) {
                my $file = $1;
                next if $file eq 'svn:this_dir';
                next if !$file or -d "../$file" or $file =~ /^\./;
                push @files, $dir ? "$dir/$file" : $file;
             }
        }
        close $fh;

    }}, $cwd);

    # files to add which aren't under svn
    push @files, qw(lib/ModPerl/DummyVersions.pm);

    return @files;
}

sub mkmanifest {
    my @files = (@add_files, get_svn_files());

    my $matches = maniskip();
    open my $fh, '>', 'MANIFEST' or die "open MANIFEST: $!";

    for my $file (sort @files) {
        if ($matches->($file)) {
            warn "skipping $file\n";
            next;
        }

        print "$file\n";
        print $fh "$file\n";
    }

    close $fh;
}

#copied from ExtUtils::Manifest
#uses DATA instead of MANIFEST.SKIP
sub maniskip {
    my $matches = sub {0};
    my @skip;

    while (<DATA>){
        chomp;
        next if /^#/;
        next if /^\s*$/;
        push @skip, $_;
    }

    my $sub = "\$matches = "
        . "sub { my (\$arg)=\@_; return 1 if "
        . join (" || ",  (map {s!/!\\/!g; "\$arg =~ m/$_/o"} @skip), 0)
        . " }";

    eval $sub;

    $matches;
}

1;
__DATA__
patches/
#very few will have Chatbot::Eliza installed
eliza
# random failures
t/perl/ithreads.t
t/perl/ithreads2.t
t/response/TestPerl/ithreads.pm
t/response/TestPerl/ithreads_args.pm
t/response/TestPerl/ithreads_eval.pm
# incomplete
t/apr-ext/perlio
# PAUSE breaks if a dist has more than one META.yml. the top-level
# META.yml already excludes Apache-Test from indexing
Apache-Test/META.yml
# exclude Apache-Test/MANIFEST since it confuses the mp2 build (e.g it
# wants Apache-Test/META.yml which we don't supply, see above)
Apache-Test/MANIFEST

# this is an internal to developers sub-project
Apache-Test/Apache-TestItSelf
