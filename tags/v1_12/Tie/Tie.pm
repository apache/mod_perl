package Apache::Tie;

use strict;
use DynaLoader ();
use vars qw(@ISA $VERSION);
@ISA = qw(DynaLoader);
$VERSION = '0.01';

if($ENV{MOD_PERL}) {
    __PACKAGE__->bootstrap($VERSION);
}
*DESTROY = \&destroy; #avoid weird xsubpp bug

1;

__END__

=head1 NAME

Apache::Tie - Tie interfaces to Apache structures

=head1 SYNOPSIS

    my $headers_out = $r->headers_out;
    while(my($key,$val) = each %$headers_out) {
    ...
    }

    my $table = $r->headers_out;
    $table->set(From => 'dougm@perl.apache.org');

=head1 DESCRIPTION

This module provides tied interfaces to Apache data structures.

=head2 CLASSES

=over 4

=item Apache::TieHashTable

The I<Apache::TieHashTable> class provides methods for interfacing
with the Apache C<table> structure.
The following I<Apache> class methods, when called in a scalar context
with no "key" argument, will return a I<HASH> reference blessed into the
I<Apache::TieHashTable> class and where I<HASH> is tied to
I<Apache::TieHashTable>: 

 headers_in
 headers_out
 err_headers_out
 notes
 dir_config
 subprocess_env

=head2 METHODS

=over 4

=item get

Corresponds to the C<ap_table_get> function.

    my $value = $table->get($key);

    my $value = $headers_out->{$key};

=item set

Corresponds to the C<ap_table_set> function.

    $table->set($key, $value);

    $headers_out->{$key} = $value;

=item unset

Corresponds to the C<ap_table_unset> function.

    $table->unset($key);

    delete $headers_out->{$key};

=item clear

Corresponds to the C<ap_table_clear> function.

    $table->clear;

    %$headers_out = ();

=item add

Corresponds to the C<ap_table_add> function.

    $table->add($key, $value);

=item merge

Corresponds to the C<ap_table_merge> function.

    $table->merge($key, $value);

=back

=back

=head1 AUTHOR

Doug MacEachern

=head1 SEE ALSO

Apache(3), mod_perl(3)

=cut
