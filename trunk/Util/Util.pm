package Apache::Util;

use strict;
use mod_perl ();
use vars qw($VERSION @EXPORT_OK %EXPORT_TAGS);

use Exporter ();
use DynaLoader ();

*unescape_uri = \&Apache::unescape_url;
*unescape_uri_info = \&Apache::unescape_url_info;

*import = \&Exporter::import;

@EXPORT_OK = qw(escape_html escape_uri unescape_uri unescape_uri_info 
		parsedate ht_time size_string);
%EXPORT_TAGS = (all => \@EXPORT_OK);
$VERSION = '1.01';

__PACKAGE__->mod_perl::boot($VERSION);

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

=item parsedate

Parses an HTTP date in one of three standard forms:

 Sun, 06 Nov 1994 08:49:37 GMT  ; RFC 822, updated by RFC 1123

 Sunday, 06-Nov-94 08:49:37 GMT ; RFC 850, obsoleted by RFC 1036

 Sun Nov  6 08:49:37 1994       ; ANSI C's asctime() format       

Example:

 my $secs = Apache::Util::parsedate($date_str);

=item ht_time

Format a time string.

Examples:

 my $str = Apache::Util::ht_time(time);

 my $str = Apache::Util::ht_time(time, "%d %b %Y %T %Z");

 my $str = Apache::Util::ht_time(time, "%d %b %Y %T %Z", 0);

=back

=head1 AUTHOR

Doug MacEachern

=head1 SEE ALSO

perl(1).

=cut
