package APR::XSLoader;

use strict;
use warnings FATAL => 'all';

use DynaLoader (); #XXX workaround for 5.6.1 bug
use XSLoader ();

BEGIN {
    unless (defined &BOOTSTRAP) {
        *BOOTSTRAP = sub () { 0 };
    }
}

sub load {
    return unless BOOTSTRAP;
    XSLoader::load(@_);
}

1;
__END__
