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
package Apache::Reload;

use strict;
use warnings FATAL => 'all';

use mod_perl 1.99;

our $VERSION = '0.09';

use Apache::Const -compile => qw(OK);

use Apache::Connection;
use Apache::ServerUtil;
use Apache::RequestUtil;

use vars qw(%INCS %Stat $TouchTime %UndefFields);

%Stat = ($INC{"Apache/Reload.pm"} => time);

$TouchTime = time;

sub import {
    my $class = shift;
    my($package,$file) = (caller)[0,1];

    $class->register_module($package, $file);
}

sub package_to_module {
    my $package = shift;
    $package =~ s/::/\//g;
    $package .= ".pm";
    return $package;
}

sub register_module {
    my($class, $package, $file) = @_;
    my $module = package_to_module($package);

    if ($file) {
        $INCS{$module} = $file;
    }
    else {
        $file = $INC{$module};
        return unless $file;
        $INCS{$module} = $file;
    }

    no strict 'refs';
    if (%{"${package}::FIELDS"}) {
        $UndefFields{$module} = "${package}::FIELDS";
    }
}

# the first argument is:
# $c if invoked as 'PerlPreConnectionHandler'
# $r if invoked as 'PerlInitHandler'
sub handler {
    my $o = shift;
    $o = $o->base_server if ref($o) eq 'Apache::Connection';

    my $DEBUG = ref($o) && (lc($o->dir_config("ReloadDebug") || '') eq 'on');

    my $TouchFile = ref($o) && $o->dir_config("ReloadTouchFile");

    my $ConstantRedefineWarnings = ref($o) && 
        (lc($o->dir_config("ReloadConstantRedefineWarnings") || '') eq 'off') 
            ? 0 : 1;

    my $TouchModules;

    if ($TouchFile) {
        warn "Checking mtime of $TouchFile\n" if $DEBUG;
        my $touch_mtime = (stat($TouchFile))[9] || return 1;
        return 1 unless $touch_mtime > $TouchTime;
        $TouchTime = $touch_mtime;
        open my $fh, $TouchFile or die "Can't open '$TouchFile': $!";
        $TouchModules = <$fh>;
        chomp $TouchModules if $TouchModules;
    }

    if (ref($o) && (lc($o->dir_config("ReloadAll") || 'on') eq 'on')) {
        *Apache::Reload::INCS = \%INC;
    }
    else {
        *Apache::Reload::INCS = \%INCS;
        my $ExtraList = 
                $TouchModules || 
                (ref($o) && $o->dir_config("ReloadModules")) || 
                '';
        my @extra = split(/\s+/, $ExtraList);
        foreach (@extra) {
            if (/(.*)::\*$/) {
                my $prefix = $1;
                $prefix =~ s/::/\//g;
                foreach my $match (keys %INC) {
                    if ($match =~ /^\Q$prefix\E/) {
                        $Apache::Reload::INCS{$match} = $INC{$match};
                        my $package = $match;
                        $package =~ s/\//::/g;
                        $package =~ s/\.pm$//;
                        no strict 'refs';
#                        warn "checking for FIELDS on $package\n";
                        if (%{"${package}::FIELDS"}) {
#                            warn "found fields in $package\n";
                            $UndefFields{$match} = "${package}::FIELDS";
                        }
                    }
                }
            }
            else {
                Apache::Reload->register_module($_);
            }
        }
    }

    my $ReloadDirs = ref($o) && $o->dir_config("ReloadDirectories");
    my @watch_dirs = split(/\s+/, $ReloadDirs||'');
    while (my($key, $file) = each %Apache::Reload::INCS) {
        next unless defined $file;
        next if @watch_dirs && !grep { $file =~ /^$_/ } @watch_dirs;
        warn "Apache::Reload: Checking mtime of $key\n" if $DEBUG;

        my $mtime = (stat $file)[9];

        unless (defined($mtime) && $mtime) {
            for (@INC) {
                $mtime = (stat "$_/$file")[9];
                last if defined($mtime) && $mtime;
            }
        }

        warn("Apache::Reload: Can't locate $file\n"), next
            unless defined $mtime and $mtime;

        unless (defined $Stat{$file}) {
            $Stat{$file} = $^T;
        }

        if ($mtime > $Stat{$file}) {
            delete $INC{$key};
#           warn "Reloading $key\n";
            if (my $symref = $UndefFields{$key}) {
#                warn "undeffing fields\n";
                no strict 'refs';
                undef %{$symref};
            }
            no warnings FATAL => 'all';
            local $SIG{__WARN__} = \&skip_redefine_const_sub_warn
                unless $ConstantRedefineWarnings;
            require $key;
            warn("Apache::Reload: process $$ reloading $key\n")
                    if $DEBUG;
        }
        $Stat{$file} = $mtime;
    }

    return Apache::OK;
}

sub skip_redefine_const_sub_warn {
    return if $_[0] =~ /^Constant subroutine [\w:]+ redefined at/;
    CORE::warn(@_);
}

1;
__END__
