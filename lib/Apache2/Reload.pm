# Copyright 2001-2005 The Apache Software Foundation
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
package Apache2::Reload;

use strict;
use warnings FATAL => 'all';

use mod_perl2;

our $VERSION = '0.09';

use Apache2::Const -compile => qw(OK);

use Apache2::Connection;
use Apache2::ServerUtil;
use Apache2::RequestUtil;

use ModPerl::Util ();

use vars qw(%INCS %Stat $TouchTime);

%Stat = ($INC{"Apache2/Reload.pm"} => time);

$TouchTime = time;

sub import {
    my $class = shift;
    my($package, $file) = (caller)[0,1];

    $class->register_module($package, $file);
}

sub package_to_module {
    my $package = shift;
    $package =~ s/::/\//g;
    $package .= ".pm";
    return $package;
}

sub module_to_package {
    my $module = shift;
    $module =~ s/\//::/g;
    $module =~ s/\.pm$//g;
    return $module;
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
}

sub unregister_module {
    my($class, $package) = @_;
    my $module = package_to_module($package);
    delete $INCS{$module};
}

# the first argument is:
# $c if invoked as 'PerlPreConnectionHandler'
# $r if invoked as 'PerlInitHandler'
sub handler {
    my $o = shift;
    $o = $o->base_server if ref($o) eq 'Apache2::Connection';

    my $DEBUG = ref($o) && (lc($o->dir_config("ReloadDebug") || '') eq 'on');

    my $TouchFile = ref($o) && $o->dir_config("ReloadTouchFile");

    my $ConstantRedefineWarnings = ref($o) && 
        (lc($o->dir_config("ReloadConstantRedefineWarnings") || '') eq 'off') 
            ? 0 : 1;

    my $TouchModules;

    if ($TouchFile) {
        warn "Checking mtime of $TouchFile\n" if $DEBUG;
        my $touch_mtime = (stat $TouchFile)[9] || return 1;
        return 1 unless $touch_mtime > $TouchTime;
        $TouchTime = $touch_mtime;
        open my $fh, $TouchFile or die "Can't open '$TouchFile': $!";
        $TouchModules = <$fh>;
        chomp $TouchModules if $TouchModules;
    }

    if (ref($o) && (lc($o->dir_config("ReloadAll") || 'on') eq 'on')) {
        *Apache2::Reload::INCS = \%INC;
    }
    else {
        *Apache2::Reload::INCS = \%INCS;
        my $ExtraList = 
                $TouchModules || 
                (ref($o) && $o->dir_config("ReloadModules")) || 
                '';
        my @extra = split /\s+/, $ExtraList;
        foreach (@extra) {
            if (/(.*)::\*$/) {
                my $prefix = $1;
                $prefix =~ s/::/\//g;
                foreach my $match (keys %INC) {
                    if ($match =~ /^\Q$prefix\E/) {
                        $Apache2::Reload::INCS{$match} = $INC{$match};
                    }
                }
            }
            else {
                Apache2::Reload->register_module($_);
            }
        }
    }

    my $ReloadDirs = ref($o) && $o->dir_config("ReloadDirectories");
    my @watch_dirs = split(/\s+/, $ReloadDirs||'');
    while (my($key, $file) = each %Apache2::Reload::INCS) {
        next unless defined $file;
        next if @watch_dirs && !grep { $file =~ /^$_/ } @watch_dirs;
        warn "Apache2::Reload: Checking mtime of $key\n" if $DEBUG;

        my $mtime = (stat $file)[9];

        unless (defined($mtime) && $mtime) {
            for (@INC) {
                $mtime = (stat "$_/$file")[9];
                last if defined($mtime) && $mtime;
            }
        }

        warn("Apache2::Reload: Can't locate $file\n"), next
            unless defined $mtime and $mtime;

        unless (defined $Stat{$file}) {
            $Stat{$file} = $^T;
        }

        if ($mtime > $Stat{$file}) {
            my $package = module_to_package($key);
            ModPerl::Util::unload_package($package);
            require $key;
            warn("Apache2::Reload: process $$ reloading $package from $key\n")
                    if $DEBUG;
        }
        $Stat{$file} = $mtime;
    }

    return Apache2::OK;
}

1;
__END__
