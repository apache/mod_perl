package ModPerl::RegistryLoader;

use Apache::Const -compile => qw(OPT_EXECCGI);
use Carp;

our @ISA = ();

sub new {
    my $class = shift;
    my $self = bless {@_} => ref($class)||$class;
    $self->load_package($self->{package});
    return $self;
}

sub handler {
    my($self, $uri, $filename) = @_;

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
        if (my $func = $self->{trans}) {
            no strict 'refs';
            $filename = $func->($uri);
            unless (-e $filename) {
                $self->warn("Cannot find a translated from uri: $filename");
                return;
            }
        } else {
            # try to guess
            (my $guess = $uri) =~ s|^/||;
            $filename = Apache::server_root_relative($guess);
            $self->warn("Trying to guess filename based on uri");
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

    my $r = bless {
		   uri      => $uri,
		   filename => $filename,
		  } => ref($self) || $self;

    $r->SUPER::handler;

}

sub filename { shift->{filename} }
sub finfo    { shift->{filename} }
sub uri      { shift->{uri} }
sub path_info {}
sub allow_options { Apache::OPT_EXECCGI } #will be checked again at run-time
sub log_error { shift; die @_ if $@; warn @_; }
*log_reason = \&log_error;
sub run {} # don't run the script
sub server { shift }

# override Apache class methods called by Modperl::Registry*. normally
# only available at request-time via blessed request_rec pointer
sub slurp_filename {
    my $r = shift;
    my $filename = $r->filename;
    open my $fh, $filename;
    local $/;
    my $code = <$fh>;
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
    Apache::warn(__PACKAGE__ . ": @_\n");
}

1;
__END__
