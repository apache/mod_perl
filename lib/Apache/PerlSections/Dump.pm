package Apache::PerlSections::Dump;

use strict;
use warnings FATAL => 'all';

our $VERSION = '0.01';

use Apache::PerlSections;
our @ISA = qw(Apache::PerlSections);

use Data::Dumper;

# Process all saved packages
sub package     { return shift->saved }

# We don't want to save anything
sub save        { return }

# We don't want to post any config to apache, we are dumping
sub post_config { return }

sub dump {
    my $self = shift;
    unless (ref $self) {
        $self = $self->new;
    }
    $self->handler();
    return join "\n", @{$self->directives}, '1;', '__END__', '';
}

sub store {
    my ($class, $filename) = @_;
    require IO::File;

    my $fh = IO::File->new(">$filename") or die "can't open $filename $!\n";

    $fh->print($class->dump);

    $fh->close;
}

sub dump_array {
     my($self, $name, $entry) = @_;
     $self->add_config(Data::Dumper->Dump([$entry], ["*$name"]));
}

sub dump_hash {
    my($self, $name, $entry) = @_;
    for my $elem (sort keys %{$entry}) {
        $self->add_config(Data::Dumper->Dump([$entry->{$elem}], ["\$$name"."{'$elem'}"])); 
    }
    
}

sub dump_entry {
    my($self, $name, $entry) = @_;
    
    return if not defined $entry;
    my $type = ref($entry);
    
    if ($type eq 'SCALAR') {
        $self->add_config(Data::Dumper->Dump([$$entry],[$name]));
    }
    if ($type eq 'ARRAY') {
        $self->dump_array($name,$entry);
    }
    else {
        $self->add_config(Data::Dumper->Dump([$entry],[$name]));
    }
}

sub dump_special {
    my($self, @data) = @_;
    
    my @dump = grep { defined } @data;
    return unless @dump;

    $self->add_config(Data::Dumper->Dump([\@dump],['*'.$self->SPECIAL_NAME]));
}



1;
__END__
