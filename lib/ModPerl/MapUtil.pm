# Copyright 2001-2004 The Apache Software Foundation
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
package ModPerl::MapUtil;

use strict;
use warnings;
use Exporter ();
use Apache::Build ();

our @EXPORT_OK = qw(list_first disabled_reason
                    function_table structure_table
                    xs_glue_dirs);

our @ISA = qw(Exporter);

my %disabled_map = (
    '!' => 'disabled or not yet implemented',
    '~' => 'implemented but not auto-generated',
    '-' => 'likely never be available to Perl',
    '>' => '"private" to apache',
    '?' => 'unclassified',
);

my $function_table = [];

sub function_table {
    return $function_table if @$function_table;
    push @INC, "xs/tables/current";
    require Apache::FunctionTable;
    require ModPerl::FunctionTable;
    @$function_table = (@$Apache::FunctionTable, @$ModPerl::FunctionTable);
    $function_table;
}

my $structure_table = [];

sub structure_table {
    return $structure_table if @$structure_table;
    require Apache::StructureTable;
    @$structure_table = (@$Apache::StructureTable);
    $structure_table;
}

sub disabled_reason {
    $disabled_map{+shift} || 'unknown';
}

sub xs_glue_dirs {
    Apache::Build->build_config->mp_xs_glue_dir;
}

sub list_first (&@) {
    my $code = shift;

    for (@_) {
        return $_ if $code->();
    }

    undef;
}

package ModPerl::MapBase;

*function_table = \&ModPerl::MapUtil::function_table;
*structure_table = \&ModPerl::MapUtil::structure_table;

sub readline {
    my $fh = shift;

    while (<$fh>) {
        chomp;
        s/^\s+//; s/\s+$//;
        s/^\#.*//;
        s/\s*\#.*//;

        next unless $_;

        if (s:\\$::) {
            my $cur = $_;
            $_ = $cur . $fh->readline;
            return $_;
        }

        return $_;
    }
}

our $MapDir;

my $map_classes = join '|', qw(type structure function);

sub map_files {
    my $self = shift;
    my $package = ref($self) || $self;

    my($wanted) = $package =~ /($map_classes)/io;

    my(@dirs) = (($MapDir || './xs'), ModPerl::MapUtil::xs_glue_dirs());

    my @files;

    for my $dir (map { -d "$_/maps" ? "$_/maps" : $_ } @dirs) {
        opendir my $dh, $dir or warn "opendir $dir: $!";

        for (readdir $dh) {
            next unless /\.map$/;

            my $file = "$dir/$_";

            if ($wanted) {
                next unless $file =~ /$wanted/i;
            }

            #print "$package => $file\n";
            push @files, $file;
        }

        closedir $dh;
    }

    return @files;
}

sub parse_keywords {
    my($self, $line) = @_;
    my %words;

    for my $pair (split /\s+/, $line) {
        my($key, $val) = split /=/, $pair;

        unless ($key and $val) {
            die "parse error ($ModPerl::MapUtil::MapFile line $.)";
        }

        $words{$key} = $val;
    }

    %words;
}

sub parse_map_files {
    my($self) = @_;

    my $map = {};

    for my $file (map_files($self)) {
        open my $fh, $file or die "open $file: $!";
        local $ModPerl::MapUtil::MapFile = $file;
        bless $fh, __PACKAGE__;
        $self->parse($fh, $map);
        close $fh;
    }

    return $map;
}

1;
__END__
