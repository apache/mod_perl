package TestCommon::Utils;

use strict;
use warnings FATAL => 'all';

BEGIN {
    # perl 5.8.0 (only) croaks on eval {} block at compile time when
    # it thinks the application is setgid. workaround: shutdown
    # compile time errors for this function
    local $SIG{__DIE__} = sub { };
    # perl 5.6.x only triggers taint protection on strings which are
    # at least one char long
    sub is_tainted {
        return ! eval { eval join '', '#', map substr($_, 0, 0), @_; 1};
    }
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

  is_tainted($data)

returns I<TRUE> if C<$data> is tainted, I<FALSE> otherwise




=cut

