package TestCommon::Utils;

use strict;
use warnings FATAL => 'all';

# perl 5.6.x only triggers taint protection on strings which are at
# least one char long
sub is_tainted {
    return ! eval {
        eval join '', '#',
            map defined() ? substr($_, 0, 0) : (), @_;
        1;
    };
}

1;

__END__

=head1 NAME

TestCommon::Utils - Common Test Utils



=head1 Synopsis

  use TestCommon::Utils;
  
  # test whether some SV is tainted
  $b->read(my $data);
  ok TestCommon::Utils::is_tainted($data);




=head1 Description

Various handy testing utils




=head1 API



=head2 is_tainted()

  is_tainted(@data);

returns I<TRUE> if at least one element in C<@data> is tainted,
I<FALSE> otherwise.




=cut

