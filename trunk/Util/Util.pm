package Apache::Util;

use strict;
use vars qw($VERSION @ISA @EXPORT_OK %EXPORT_TAGS);

use Exporter ();
use DynaLoader ();

@ISA = qw(Exporter DynaLoader);
@EXPORT_OK = qw(escape_html escape_uri);
%EXPORT_TAGS = (all => \@EXPORT_OK);
$VERSION = '0.01';

if($ENV{MOD_PERL}) {
    bootstrap Apache::Util $VERSION;
}

1;
__END__


=head1 NAME

Apache::Util - Interface to Apache C util functions

=head1 SYNOPSIS

  use Apache::Util qw(:all);

=head1 DESCRIPTION

This module provides a Perl interface to some of the C utility functions
available in Perl.  The same functionality is avaliable in libwww-perl, but
the C versions are faster:

    use Benchmark;
    timethese(1000, {
        C => sub { my $esc = Apache::Util::escape_html($html) },
        Perl => sub { my $esc = HTML::Entities::encode($html) },
    });  

    Benchmark: timing 1000 iterations of C, Perl...
            C:  0 secs ( 0.17 usr  0.00 sys =  0.17 cpu)
         Perl: 15 secs (15.06 usr  0.04 sys = 15.10 cpu) 

    use Benchmark;
    timethese(10000, {
        C => sub { my $esc = Apache::Util::escape_uri($uri) },
        Perl => sub { my $esc = URI::Escape::uri_escape($uri) },
    }); 

    Benchmark: timing 10000 iterations of C, Perl...
            C:  0 secs ( 0.55 usr  0.01 sys =  0.56 cpu)
         Perl:  2 secs ( 1.78 usr  0.01 sys =  1.79 cpu) 

=head1 FUNCTIONS

=over 4

=item escape_html

This routine replaces unsafe characters in $string with their entity
representation.

 my $esc = Apache::Util::escape_html($html);

=item escape_uri

This function replaces all unsafe characters in the $string with their
escape sequence and returns the result.

 my $esc = Apache::Util::escape_uri($uri);

=back

=head1 AUTHOR

Doug MacEachern

=head1 SEE ALSO

perl(1).

=cut
