# Copyright 2003-2004 The Apache Software Foundation
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
package Apache::PerlSections;

use strict;
use warnings FATAL => 'all';

our $VERSION = '0.01';

use Apache::CmdParms ();
use Apache::Directive ();
use APR::Table ();
use Apache::Server ();
use Apache::ServerUtil ();
use Apache::Const -compile => qw(OK);

use constant SPECIAL_NAME => 'PerlConfig';
use constant SPECIAL_PACKAGE => 'Apache::ReadConfig';

sub new {
    my($package, @args) = @_;
    return bless { @args }, ref($package) || $package;
}

sub server     { return shift->{'parms'}->server() }
sub directives { return shift->{'directives'} ||= [] }
sub package    { return shift->{'args'}->{'package'} }

my @saved;
sub save       { return $Apache::Server::SaveConfig }
sub saved      { return @saved }

sub handler : method {
    my($self, $parms, $args) = @_;

    unless (ref $self) {
        $self = $self->new('parms' => $parms, 'args' => $args);
    }

    if ($self->save) {
        push @saved, $self->package;
    }

    my $special = $self->SPECIAL_NAME;

    for my $entry ($self->symdump()) {
        if ($entry->[0] !~ /$special/) {
            $self->dump_any(@$entry);
        }
    }

    {
        no strict 'refs';
        foreach my $package ($self->package) {
            $self->dump_special(${"${package}::$special"},
              @{"${package}::$special"} );
        }
    }

    $self->post_config();

    Apache::OK;
}

sub symdump {
    my($self) = @_;

    unless ($self->{symbols}) {
        no strict;
        
        $self->{symbols} = [];
        
        #XXX: Here would be a good place to warn about NOT using 
        #     Apache::ReadConfig:: directly in <Perl> sections
        foreach my $pack ($self->package, $self->SPECIAL_PACKAGE) {
            #XXX: Shamelessly borrowed from Devel::Symdump;
            while (my ($key, $val) = each(%{ *{"$pack\::"} })) {
                #We don't want to pick up stashes...
                next if ($key =~ /::$/);
                local (*ENTRY) = $val;
                if (defined $val && defined *ENTRY{SCALAR}) {
                    push @{$self->{symbols}}, [$key, $ENTRY];
                }
                if (defined $val && defined *ENTRY{ARRAY}) {
                    push @{$self->{symbols}}, [$key, \@ENTRY];
                }
                if (defined $val && defined *ENTRY{HASH} && $key !~ /::/) {
                    push @{$self->{symbols}}, [$key, \%ENTRY];
                }
            }
        }
    }

    return @{$self->{symbols}};
}

sub dump_special {
    my($self, @data) = @_;
    $self->add_config(@data);
}

sub dump_any {
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

sub dump {
    my $class = shift;
    require Apache::PerlSections::Dump;
    return Apache::PerlSections::Dump->dump(@_);
}

sub store {
    my $class = shift;
    require Apache::PerlSections::Dump;
    return Apache::PerlSections::Dump->store(@_);
}

1;
__END__
