# Copyright 2002-2004 The Apache Software Foundation
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
    Apache-Test/META.yml
};

my @repos = qw(
    Apache-Test
    docs
);

sub get_svn_files {
    my @files;
    foreach my $repos ('', @repos) {
        foreach my $ent (`svn ls -R $repos`) {
            chomp($ent);
            $ent = File::Spec->catfile($repos, $ent) if $repos;
            push @files, $ent if -f $ent;
        }
    }
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
        . "sub { my(\$arg)=\@_; return 1 if "
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
# incomplete
t/apr-ext/perlio
# gets some random failures, need more testing
t/response/TestModperl/util.pm
