package Apache::RegistryLoader;
use 5.003_97;
use mod_perl 1.01;
use strict;
use Apache::Registry ();
use Apache::Constants qw(OPT_EXECCGI);
@Apache::RegistryLoader::ISA = qw(Apache::Registry);
$Apache::RegistryLoader::VERSION = (qw$Revision$)[1];

sub new { 
    my $class = shift;
    bless {@_} => $class;
}

sub handler {
    my($self, $uri, $filename) = @_;

    unless($filename) {
	if(my $func = $self->{trans}) {
	    no strict 'refs';
	    $filename = &{$func}($uri);
	}
    }

    #warn "RegistryLoader: uri=$uri, filename=$filename\n";

    my $r = bless {
	uri => $uri,
	filename => Apache->server_root_relative($filename || $uri),
    } => ref($self) || $self;

    $r->SUPER::handler;
}

#override Apache class methods called by Apache::Registry
#normally only available at request-time via blessed request_rec pointer

sub filename { shift->{filename} }
sub uri { shift->{uri} }
sub status {200}
sub path_info {}
sub log_error { shift; die @_ if $@; warn @_; }
*log_reason = \&log_error; 
sub allow_options { OPT_EXECCGI } #will be checked again at run-time
sub clear_rgy_endav {}
sub request {}
sub seqno {0} 
sub server { shift }
sub is_virtual {0}
sub header_out {""}

1;

__END__

=head1 NAME 

Apache::RegistryLoader - Compile Apache::Registry scripts at server startup

=head1 SYNOPSIS

 #in PerlScript

 use Apache::RegistryLoader ();

 my $r = Apache::RegistryLoader->new;

 $r->handler($uri, $filename);

=head1 DESCRIPTION

This modules allows compilation of B<Apache::Registry> scripts at
server startup.  The script's handler routine is compiled by the 
parent server, of which children get a copy.  
The Apache::RegistryLoader C<handler> method takes arguments of C<uri> 
and the C<filename>.  URI to filename translation normally doesn't
happen until HTTP request time, so we're forced to roll our own
translation.

If filename is omitted and a C<trans> routine was not
defined, the loader will try using the B<uri> relative to
B<ServerRoot>.  Example:

 #in httpd.conf
 ServerRoot /opt/www/apache
 Alias /perl/ /opt/www/apache/perl
 
 #in PerlScript
 use Apache::RegistryLoader ();

 #/opt/www/apache/perl/test.pl 
 #is the script loaded from disk here: 
 Apache::RegistryLoader->new->handler("/perl/test.pl");

To make the loader smarter about the uri->filename translation, you may
provide the C<new> method with a C<trans> function to translate the
uri to filename.   

The following example will pre-load all files ending with C<.pl> in the
B<perl-scripts/> directory relative to B<ServerRoot>. 
The example code assumes the Location URI C</perl> is an B<Alias> to 
this directory.

 {
     use Cwd ();
     use Apache::RegistryLoader ();
     use DirHandle ();
     use strict;

     my $dir = Apache->server_root_relative("perl-scripts/");

     my $rl = Apache::RegistryLoader->new(trans => sub {
	 my $uri = shift; 
         $uri =~ s:^/perl/:/perl-scripts/:;
	 return Apache->server_root_relative($uri);
     });

     my $dh = DirHandle->new($dir) or die $!;

     for my $file ($dh->read) {
	 next unless $file =~ /\.pl$/;
	 $rl->handler("/perl/$file");
     }
 }

=head1 AUTHOR

Doug MacEachern

=head1 SEE ALSO

Apache::Registry(3), Apache(3), mod_perl(3)
