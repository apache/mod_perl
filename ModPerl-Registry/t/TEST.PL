#!perl

use strict;
use warnings FATAL => 'all';

use lib map {("../blib/$_", "../../blib/$_")} qw(lib arch);

use Apache::TestRunPerl ();

package MyTest;

our @ISA = qw(Apache::TestRunPerl);

# subclass new_test_config to add some config vars which will be
# replaced in generated httpd.conf
sub new_test_config {
    my $self = shift;

    $self->{conf_opts}->{maxclients} = 2;

    return $self->SUPER::new_test_config;
}

MyTest->new->run(@ARGV);
