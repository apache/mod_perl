package Apache::PerlSection;

use strict;
use warnings FATAL => 'all';

our $VERSION = '0.01';

use ModPerl::Symdump ();

use Apache::CmdParms ();
use Apache::Directive ();

use constant SPECIAL_NAME => 'PerlConfig';

sub new {
    my($package, @args) = @_;
    return bless { @args }, ref($package) || $package;
}

sub server     { return shift->{'parms'}->server() }
sub directives { return shift->{'directives'} ||= [] }

sub handler : method {
    my($self, $parms, $args) = @_;

    unless (ref $self) {
        $self = $self->new('parms' => $parms, 'args' => $args);
    }

    my $package = $args->get('package');
    my $special = $self->SPECIAL_NAME;
	
    my $root = ModPerl::Symdump->new($package);

    my %convert = (
        'scalars' => sub { no strict 'refs'; return ${ $_[0] } },
        'arrays'  => sub { no strict 'refs'; return \@{ $_[0] } },
        'hashes'  => sub { no strict 'refs'; return \%{ $_[0] } },
    );

    for my $type (sort keys %convert) {
        for my $entry (grep { !/$special/ } $root->$type()) {
            (my $name = $entry) =~ s/${package}:://;
            $self->dump($name, $convert{$type}->($entry));
        }
    }

    {
        no strict 'refs';
        $self->dump_special(${"${package}::$special"},
          @{"${package}::$special"} );
    }

    $self->post_config();

    Apache::OK;
}

sub dump_special {
    my($self, @data) = @_;
    $self->add_config(@data);
}

sub dump {
    my($self, $name, $entry) = @_;
    my $type = ref $entry;

    if ($type eq 'ARRAY') {
        $self->dump_array($name, $entry);
    }
    elsif ($type eq 'HASH') {
        $self->dump_hash($name, $entry);
    }
    else {
        $self->dump_entry($name, $entry);
    }
}

sub dump_hash {
    my($self, $name, $hash) = @_;

    for my $entry (sort keys %{ $hash || {} }) {
        my $item = $hash->{$entry};
        my $type = ref($item);

        if ($type eq 'HASH') {
            $self->dump_section($name, $entry, $item);
        }
        elsif ($type eq 'ARRAY') {
            for my $e (@$item) {
                $self->dump_section($name, $entry, $e);
            }
        }
    }
}

sub dump_section {
    my($self, $name, $loc, $hash) = @_;

    $self->add_config("<$name $loc>\n");

    for my $entry (sort keys %{ $hash || {} }) {
        $self->dump_entry($entry, $hash->{$entry});
    }

    $self->add_config("</$name>\n");
}

sub dump_array {
    my($self, $name, $entries) = @_;

    for my $entry (@$entries) {
        $self->dump_entry($name, $entry);
    }
}

sub dump_entry {
    my($self, $name, $entry) = @_;
    my $type = ref $entry;

    if ($type eq 'SCALAR') {
        $self->add_config("$name $$entry\n");
    }
    elsif ($type eq 'ARRAY') {
        $self->add_config("$name @$entry\n");
    }
    elsif ($type eq 'HASH') {
        $self->dump_hash($name, $entry);
    }
    elsif ($type) {
        #XXX: Could do $type->can('httpd_config') here on objects ???
        die "Unknown type '$type' for directive $name";
    }
    elsif (defined $entry) {
        $self->add_config("$name $entry\n");
    }
}

sub add_config {
    my($self, $config) = @_;
    return unless defined $config;
    chomp($config);
    push @{ $self->directives }, $config;
}

sub post_config {
    my($self) = @_;
    my $errmsg = $self->server->add_config($self->directives);
    die $errmsg if $errmsg;
}

1;
__END__
