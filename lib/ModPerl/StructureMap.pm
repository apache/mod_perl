package ModPerl::StructureMap;

use strict;
use warnings FATAL => 'all';
use ModPerl::MapUtil qw(structure_table);

our @ISA = qw(ModPerl::MapBase);

sub new {
    my $class = shift;
    bless {}, $class;
}

sub generate {
    my $self = shift;
    my $map = $self->get;

    for my $entry (@{ structure_table() }) {
        my $type = $entry->{type};
        my $elts = $entry->{elts};

        next unless @$elts;
        next if $type =~ $self->{IGNORE_RE};
        next unless grep {
            not exists $map->{$type}->{ $_->{name} }
        } @$elts;

        print "<$type>\n";
        for my $e (@$elts) {
            print "   $e->{name}\n";
        }
        print "</$type>\n\n";
    }
}

sub disabled { shift->{disabled} }

sub check {
    my $self = shift;
    my $map = $self->get;

    my @missing;

    for my $entry (@{ structure_table() }) {
        my $type = $entry->{type};

        for my $name (map $_->{name}, @{ $entry->{elts} }) {
            next if exists $map->{$type}->{$name};
            next if $type =~ $self->{IGNORE_RE};
            push @missing, "$type.$name";
        }
    }

    return @missing ? \@missing : undef;
}

sub check_exists {
    my $self = shift;

    my %structures;
    for my $entry (@{ structure_table() }) {
        $structures{ $entry->{type} } = { map {
            $_->{name}, 1
        } @{ $entry->{elts} } };
    }

    my @missing;

    while (my($type, $elts) = each %{ $self->{map} }) {
        for my $name (keys %$elts) {
            next if exists $structures{$type}->{$name};
            push @missing, "$type.$name";
        }
    }

    return @missing ? \@missing : undef;
}

sub parse {
    my($self, $fh, $map) = @_;

    my($disabled, $class);
    my %cur;

    while ($fh->readline) {
        if (m:^(\W?)</?([^>]+)>:) {
            my $args;
            $disabled = $1;
            ($class, $args) = split /\s+/, $2, 2;

            %cur = ();
            if ($args and $args =~ /E=/) {
                %cur = $self->parse_keywords($args);
            }

            $self->{MODULES}->{$class} = $cur{MODULE} if $cur{MODULE};

            next;
        }
        elsif (s/^(\w+):\s*//) {
            push @{ $self->{$1} }, split /\s+/;
            next;
        }

        if (s/^(\W)\s*// or $disabled) {
            $map->{$class}->{$_} = undef;
            push @{ $self->{disabled}->{ $1 || '!' } }, "$class.$_";
        }
        else {
            $map->{$class}->{$_} = 1;
        }
    }

    if (my $ignore = $self->{IGNORE}) {
        $ignore = join '|', @$ignore;
        $self->{IGNORE_RE} = qr{^($ignore)};
    }
    else {
        $self->{IGNORE_RE} = qr{^$};
    }
}

sub get {
    my $self = shift;

    $self->{map} ||= $self->parse_map_files;
}

1;
__END__
