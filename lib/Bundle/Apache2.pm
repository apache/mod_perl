package Bundle::Apache2;

$VERSION = '1.00';

1;

__END__

=head1 NAME

Bundle::Apache2 - Install Apache mod_perl2 and related modules

=head1 SYNOPSIS

C<perl -MCPAN -e 'install Bundle::Apache2'>

=head1 CONTENTS

LWP                   - Used in testing

Chatbot::Eliza        - Used in testing

Devel::Symdump        - Symbol table browsing with Apache::Status

CGI  2.87             - Used in testing (it's in core, but some vendors exclude it)

=head1 DESCRIPTION

This bundle contains modules used by Apache mod_perl2.

Asking CPAN.pm to install a bundle means to install the bundle itself
along with all the modules contained in the CONTENTS section
above. Modules that are up to date are not installed, of course.

=head1 AUTHOR

Doug MacEachern, Stas Bekman
