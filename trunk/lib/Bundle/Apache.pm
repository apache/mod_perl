package Bundle::Apache;

$VERSION = '1.01';

1;

__END__

=head1 NAME

Bundle::Apache - Install Apache mod_perl and related modules

=head1 SYNOPSIS

C<perl -MCPAN -e 'install Bundle::Apache'>

=head1 CONTENTS

Apache - Perl interface to Apache server API

ExtUtils::Embed - Needed to build httpd

MIME::Base64 - Needed for LWP

URI::URL - Needed for LWP

LWP - Web client to run mod_perl tests

HTML::TreeBuilder - Used for Apache::SSI

Devel::Symdump - Symbol table browsing with Apache::Status

Data::Dumper - Used by Apache::PerlSections->dump

CGI - CGI.pm

Tie::IxHash - For order in <Perl> sections

Apache::DBI   - Wrapper around DBI->connect to transparently maintain persistent connections

Apache::DB - Run the interactive Perl debugger under mod_perl

Apache::Stage - Management of document staging directories

Apache::Sandwich - Layered document maker

Apache::Request - Effective methods for dealing with client request data

=head1 DESCRIPTION

This bundle contains modules used by Apache mod_perl.

Asking CPAN.pm to install a bundle means to install the bundle itself
along with all the modules contained in the CONTENTS section
above. Modules that are up to date are not installed, of course.

=head1 AUTHOR

Doug MacEachern

