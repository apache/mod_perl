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
package ModPerl::RegistryLoader;

use strict;
use warnings;

use ModPerl::RegistryCooker ();
use APR::Pool ();

use Apache::Const -compile => qw(OK HTTP_OK OPT_EXECCGI);
use Carp;

our @ISA = ();

sub new {
    my $class = shift;
    my $self = bless {@_} => ref($class)||$class;
    $self->{package} ||= 'ModPerl::Registry';
    $self->{pool} = APR::Pool->new();
    $self->load_package($self->{package});
    return $self;
}

sub handler {
    my($self, $uri, $filename, $virthost) = @_;

    # set the inheritance rules at run time
    @ISA = $self->{package};

    unless (defined $uri) {
        $self->warn("uri is a required argument");
        return;
    }

    if (defined $filename) {
        unless (-e $filename) {
            $self->warn("Cannot find: $filename");
            return;
        }
    }
    else {
        # try to translate URI->filename
        if (exists $self->{trans} and ref($self->{trans}) eq 'CODE') {
            no strict 'refs';
            $filename = $self->{trans}->($uri);
            unless (-e $filename) {
                $self->warn("Cannot find a translated from uri: $filename");
                return;
            }
        }
        else {
            # try to guess
            (my $guess = $uri) =~ s|^/||;

            $self->warn("Trying to guess filename based on uri")
                if $self->{debug};

            $filename = Apache::server_root_relative($self->{pool}, $guess);
            unless (-e $filename) {
                $self->warn("Cannot find guessed file: $filename",
                            "provide \$filename or 'trans' sub");
                return;
            }
        }
    }

    if ($self->{debug}) {
        $self->warn("*** uri=$uri, filename=$filename");
    }

    my $rl = bless {
        uri      => $uri,
        filename => $filename,
        package  => $self->{package},
    } => ref($self) || $self;

    $rl->{virthost} = $virthost if defined $virthost;

    # can't call SUPER::handler here, because it usually calls new()
    # and then the ModPerlRegistryLoader::new() will get called,
    # instead of the super class' new, so we implement the super
    # class' handler here. Hopefully all other subclasses use the same
    # handler.
    __PACKAGE__->SUPER::new($rl)->default_handler();

}

# XXX: s/my_// for qw(my_finfo my_slurp_filename);
# when when finfo() and slurp_filename() are ported to 2.0 and
# RegistryCooker is starting to use them

sub get_server_name { return $_[0]->{virthost} if exists $_[0]->{virthost} }
sub filename { shift->{filename} }
sub status { Apache::HTTP_OK }
sub my_finfo    { shift->{filename} }
sub uri      { shift->{uri} }
sub path_info {}
sub allow_options { Apache::OPT_EXECCGI } #will be checked again at run-time
sub log_error { shift; die @_ if $@; warn @_; }
sub run { return Apache::OK } # don't run the script
sub server { shift }
sub is_virtual { exists shift->{virthost} }

# the preloaded file needs to be precompiled into the package
# specified by the 'package' attribute, not RegistryLoader
sub namespace_root {
    join '::', ModPerl::RegistryCooker::NAMESPACE_ROOT,
        shift->{REQ}->{package};
}

# override Apache class methods called by Modperl::Registry*. normally
# only available at request-time via blessed request_rec pointer
sub slurp_filename {
    my $r = shift;
    my $tainted = @_ ? shift : 1;
    my $filename = $r->filename;
    open my $fh, $filename or die "can't open $filename: $!";
    local $/;
    my $code = <$fh>;
    unless ($tainted) {
        ($code) = $code =~ /(.*)/s; # untaint
    }
    close $fh;
    return \$code;
}

sub load_package {
    my($self, $package) = @_;

    croak "package to load wasn't specified" unless defined $package;

    $package =~ s|::|/|g;
    $package .= ".pm";
    require $package;
};

sub warn {
    my $self = shift;
    Apache->warn(__PACKAGE__ . ": @_\n");
}

1;
__END__
