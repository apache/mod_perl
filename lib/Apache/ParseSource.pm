package Apache::ParseSource;

use strict;
use Apache::Build ();
use Config ();

our $VERSION = '0.02';

sub new {
    my $class = shift;

    my $self = bless {
        config => Apache::Build->new,
        @_,
    }, $class;

    my $prefixes = join '|', @{ $self->{prefixes} || [qw(ap_ apr_)] };
    $self->{prefix_re} = qr{^($prefixes)};

    $Apache::Build::APXS ||= $self->{apxs};

    $self;
}

sub config {
    shift->{config};
}

sub parse {
    my $self = shift;

    $self->{scan_filename} = $self->generate_cscan_file;

    $self->{c} = $self->scan;
}

sub DESTROY {
    my $self = shift;
    unlink $self->{scan_filename}
}

{
    package Apache::ParseSource::Scan;

    our @ISA = qw(C::Scan);

    sub get {
        local $SIG{__DIE__} = \&Carp::confess;
        shift->SUPER::get(@_);
    }
}

sub scan {
    require C::Scan;
    C::Scan->VERSION(0.75);
    require Carp;

    my $self = shift;

    my $c = C::Scan->new(filename => $self->{scan_filename});

    $c->set(includeDirs => $self->includes);
    $c->set(Defines => '-DCORE_PRIVATE');

    bless $c, 'Apache::ParseSource::Scan';
}

sub include_dir { shift->config->apxs(-q => 'INCLUDEDIR') }

sub includes { shift->config->includes }

sub find_includes {
    my $self = shift;

    return $self->{includes} if $self->{includes};

    require File::Find;

    my $dir = $self->include_dir;

    unless (-d $dir) {
        die "could not find include directory";
    }

    my @includes;
    my $unwanted = join '|', qw(ap_listen internal);

    File::Find::finddepth({
                           wanted => sub {
                               return unless /\.h$/;
                               return if /($unwanted)/o;
                               my $dir = $File::Find::dir;
                               push @includes, "$dir/$_";
                           },
                           follow => 1,
                          }, $dir);

    #include apr_*.h before the others
    my @wanted = grep { /apr_\w+\.h$/ } @includes;
    push @wanted, grep { !/apr_\w+\.h$/ } @includes;

    return $self->{includes} = \@wanted;
}

sub generate_cscan_file {
    my $self = shift;

    my $includes = $self->find_includes;

    my $filename = '.apache_includes';

    open my $fh, '>', $filename or die "can't open $filename: $!";
    for (@$includes) {
        print $fh qq(\#include "$_"\n);
    }
    close $fh;

    return $filename;
}


my $defines_wanted = join '|', qw{
OK DECLINED DONE
DECLINE_CMD DIR_MAGIC_TYPE
METHODS
HTTP_ M_ OPT_ SATISFY_ REMOTE_
OR_ ACCESS_CONF RSRC_CONF
};

my $defines_unwanted = join '|', qw{
HTTP_VERSION
};

my %enums_wanted = map { $_, 1 } qw(cmd_how);

sub get_constants {
    my($self) = @_;

    my $includes = $self->find_includes;
    my @constants;

    for my $file (@$includes) {
        open my $fh, $file or die "open $file: $!";
        while (<$fh>) {
            if (s/^\#define\s+//) {
                next unless /^($defines_wanted)/o;
                next if /^($defines_unwanted)/o;
                push @constants, (split /\s+/)[0];
            } elsif (m/^\s*enum\s+(\w+)\s+\{/) {
                my $e = $self->get_enum($1, $fh);
                push @constants, @$e if $e;
            }
        }
        close $fh;
    }

    return \@constants;
}

sub get_enum {
    my($self, $name, $fh) = @_;

    return unless $enums_wanted{$name};
    local $_;
    my @e;

    while (<$fh>) {
        last if /\};/;
        next unless /^\s*(\w+)/;
        push @e, $1;
    }

    return \@e;
}

sub wanted_functions  { shift->{prefix_re} }
sub wanted_structures { shift->{prefix_re} }

sub get_functions {
    my $self = shift;

    my $key = 'parsed_fdecls';
    return $self->{$key} if $self->{$key};

    my $c = $self->{c};

    my $fdecls = $c->get($key);

    my %seen;
    my $wanted = $self->wanted_functions;

    my @functions;

    for my $entry (@$fdecls) {
        my($rtype, $name, $args) = @$entry;
        next unless $name =~ $wanted;
        next if $seen{$name}++;

        for (qw(static __inline__)) {
            $rtype =~ s/^$_\s+//;
        }

        my $func = {
           name => $name,
           return_type => $rtype,
           args => [map {
               { type => $_->[0], name => $_->[1] }
           } @$args],
        };

        push @functions, $func;
    }

    $self->{$key} = \@functions;
}

sub get_structs {
    my $self = shift;

    my $key = 'typedef_structs';
    return $self->{$key} if $self->{$key};

    my $c = $self->{c};

    my $typedef_structs = $c->get($key);

    my %seen;
    my $wanted = $self->wanted_structures;
    my $other  = join '|', qw(_rec module
                              piped_log uri_components htaccess_result
                              cmd_parms cmd_func cmd_how);

    my @structures;
    my $sx = qr(^struct\s+);

    while (my($type, $elts) = each %$typedef_structs) {
        next unless $type =~ $wanted or $type =~ /($other)$/o;

        $type =~ s/$sx//;

        next if $seen{$type}++;

        my $struct = {
           type => $type,
           elts => [map {
               my $type = $_->[0];
               $type =~ s/$sx//;
               $type .= $_->[1] if $_->[1];
               $type =~ s/:\d+$//; #unsigned:1
               { type => $type, name => $_->[2] }
           } @$elts],
        };

        push @structures, $struct;
    }

    $self->{$key} = \@structures;
}

sub write_functions_pm {
    my $self = shift;
    my $file = shift || 'FunctionTable.pm';
    my $name = shift || 'Apache::FunctionTable';

    $self->write_pm($file, $name, $self->get_functions);
}

sub write_structs_pm {
    my $self = shift;
    my $file = shift || 'StructureTable.pm';
    my $name = shift || 'Apache::StructureTable';

    $self->write_pm($file, $name, $self->get_structs);
}

sub write_pm {
    my($self, $file, $name, $data) = @_;

    require Data::Dumper;
    local $Data::Dumper::Indent = 1;

    my($subdir) = (split '::', $name)[0];

    if (-d "lib/$subdir") {
        $file = "lib/$subdir/$file";
    }

    open my $pm, '>', $file or die "open $file: $!";

    my $dump = Data::Dumper->new([$data],
                                 [$name])->Dump;

    my $package = ref($self) || $self;
    my $version = $self->VERSION;
    my $date = scalar localtime;

    print $pm <<EOF;
package $name;

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# ! WARNING: generated by $package/$version
# !          $date
# !          do NOT edit, any changes will be lost !
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

$dump

1;
EOF
    close $pm;
}

1;
__END__
