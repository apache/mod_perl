package TestCommon::Utils;

sub is_tainted {
    my $data = shift;
    # the append of " " is crucial with older Perls (5.6), which won't
    # consider a scalar with PV = ""\0 as tainted, even though it has
    # the taint magic attached
    eval { eval $data . " " };
    return ($@ && $@ =~ qr/Insecure dependency in eval/) ? 1 : 0;
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

