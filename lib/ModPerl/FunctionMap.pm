package ModPerl::FunctionMap;

use strict;
use warnings FATAL => 'all';
use ModPerl::MapUtil qw();
use ModPerl::ParseSource ();

our @ISA = qw(ModPerl::MapBase);

sub new {
    my $class = shift;
    bless {}, $class;
}

#for adding to function.map
sub generate {
    my $self = shift;

    my $missing = $self->check;
    return unless $missing;

    print " $_\n" for @$missing;
}

sub disabled { shift->{disabled} }

#look for functions that do not exist in *.map
sub check {
    my $self = shift;
    my $map = $self->get;

    my @missing;
    my $mp_func = ModPerl::ParseSource->wanted_functions;

    for my $name (map $_->{name}, @{ $self->function_table() }) {
        next if exists $map->{$name};
        push @missing, $name unless $name =~ /^($mp_func)/o;
    }

    return @missing ? \@missing : undef;
}

#look for functions in *.map that do not exist
my $special_name = qr{(^DEFINE_|DESTROY$)};

sub check_exists {
    my $self = shift;

    my %functions = map { $_->{name}, 1 } @{ $self->function_table() };
    my @missing = ();

    for my $name (keys %{ $self->{map} }) {
        next if $functions{$name};
        push @missing, $name unless $name =~ $special_name;
    }

    return @missing ? \@missing : undef;
}

my $keywords = join '|', qw(MODULE PACKAGE PREFIX);

sub guess_prefix {
    my $entry = shift;

    my($name, $class) = ($entry->{name}, $entry->{class});
    my $prefix = "";
    $name =~ s/^DEFINE_//;

    (my $guess = lc($entry->{class} || $entry->{module}) . '_') =~ s/::/_/g;
    $guess =~ s/apache_/ap_/;

    if ($name =~ /^$guess/) {
        $prefix = $guess;
    }
    else {
        if ($name =~ /^(apr?_)/) {
            $prefix = $1;
        }
    }

    #print "GUESS prefix=$guess, name=$entry->{name} -> $prefix\n";

    return $prefix;
}

sub parse {
    my($self, $fh, $map) = @_;
    my %cur;
    my $disabled = 0;

    while ($fh->readline) {
        if (/($keywords)=/o) {
            $disabled = s/^\W//; #module is disabled
            my %words = $self->parse_keywords($_);

            if ($words{MODULE}) {
                %cur = ();
            }

            for (keys %words) {
                $cur{$_} = $words{$_};
            }

            next;
        }

        my($name, $dispatch, $argspec, $alias) = split /\s*\|\s*/;
        my $return_type;

        if ($name =~ s/^([^:]+)://) {
            $return_type = $1;
        }

        if ($name =~ s/^(\W)// or not $cur{MODULE} or $disabled) {
            #notimplemented or cooked by hand
            $map->{$name} = undef;
            push @{ $self->{disabled}->{ $1 || '!' } }, $name;
            next;
        }

        my $entry = $map->{$name} = {
           name        => $alias || $name,
           dispatch    => $dispatch,
           argspec     => $argspec ? [split /\s*,\s*/, $argspec] : "",
           return_type => $return_type,
           alias       => $alias,
        };

        if (my $package = $cur{PACKAGE}) {
            unless ($package eq 'guess') {
                $cur{CLASS} = $package;
            }
        }
        else {
            $cur{CLASS} = $cur{MODULE};
        }

        for (keys %cur) {
            $entry->{lc $_} = $cur{$_};
        }

        $entry->{prefix} ||= guess_prefix($entry);

        #avoid 'use of uninitialized value' warnings
        $entry->{$_} ||= "" for keys %{ $entry };
        if ($entry->{dispatch} =~ /_$/) {
            $entry->{dispatch} .= $name;
        }
    }
}

sub get {
    my $self = shift;

    $self->{map} ||= $self->parse_map_files;
}

sub prefixes {
    my $self = shift;
    $self = ModPerl::FunctionMap->new unless ref $self;

    my $map = $self->get;
    my %prefix;

    while (my($name, $ent) = each %$map) {
        next unless $ent->{prefix};
        $prefix{ $ent->{prefix} }++;
    }

    [keys %prefix]
}

1;
__END__
