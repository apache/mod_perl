package Apache::XSLoader;

use strict;
use warnings FATAL => 'all';

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
