package TestAPI::r_subclass;

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
our @ISA = qw(Apache::RequestRec);

use Apache::Test;

use Apache::Const -compile => 'OK';

sub new {
    my $class = shift;
    my $r = shift;
    bless { r => $r }, $class;
}

my $location = '/' . __PACKAGE__;

sub handler {
    my $r = __PACKAGE__->new(shift);

    plan $r, tests => 4;

    ok $r->uri eq $location;

    ok ((bless { r => $r })->uri eq $location); #nested

    eval { (bless {})->uri };

    ok $@ =~ /no .* key/;

    eval { (bless [])->uri };

    ok $@ =~ /unsupported/;

    Apache::OK;
}

1;
