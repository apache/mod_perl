package Apache::Reload;

use strict;
use warnings FATAL => 'all';

use mod_perl 1.99;

our $VERSION = '0.08';

require Apache::RequestUtil;

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

sub handler {
    my $r = shift;

    my $DEBUG = ref($r) && (lc($r->dir_config("ReloadDebug") || '') eq 'on');

    my $TouchFile = ref($r) && $r->dir_config("ReloadTouchFile");

    my $TouchModules;

    if ($TouchFile) {
        warn "Checking mtime of $TouchFile\n" if $DEBUG;
        my $touch_mtime = (stat($TouchFile))[9] || return 1;
        return 1 unless $touch_mtime > $TouchTime;
        $TouchTime = $touch_mtime;
        open my $fh, $TouchFile or die "Can't open '$TouchFile': $!";
        $TouchModules = <$fh>;
        chomp $TouchModules;
    }

    if (ref($r) && (lc($r->dir_config("ReloadAll") || 'on') eq 'on')) {
        *Apache::Reload::INCS = \%INC;
    }
    else {
        *Apache::Reload::INCS = \%INCS;
        my $ExtraList = 
                $TouchModules || 
                (ref($r) && $r->dir_config("ReloadModules")) || 
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

    my $ReloadDirs = ref($r) && $r->dir_config("ReloadDirectories");
    my @watch_dirs = split(/\s+/, $ReloadDirs||'');
    while (my($key, $file) = each %Apache::Reload::INCS) {
        next if @watch_dirs && !grep { $file =~ /^$_/ } @watch_dirs;
        warn "Apache::Reload: Checking mtime of $key\n" if $DEBUG;

        my $mtime = (stat $file)[9];

        unless (defined($mtime) && $mtime) {
            for (@INC) {
                $mtime = (stat "$_/$file")[9];
                last if defined($mtime) && $mtime;
            }
        }

        warn("Apache::Reload: Can't locate $file\n"),next 
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
            require $key;
            warn("Apache::Reload: process $$ reloading $key\n")
                    if $DEBUG;
        }
        $Stat{$file} = $mtime;
    }

    return 1;
}

1;
__END__
