package TestCommon::Utils;

sub is_tainted {
    my $data = shift;
    eval { eval $data };
    return ($@ && $@ =~ qr/Insecure dependency in eval/) ? 1 : 0;
}

1;

__END__

=head1 NAME

TestCommon::Utils - Common Test Utils



=head1 Synopsis

  use TestCommon::Utils;
  
  $b->read(my $data);




=head1 Description

Various handy testing utils




=head1 API



=head2 is_tainted()

  is_tainted($data)

returns I<TRUE> if C<$data> is tainted, I<FALSE> otherwise




=cut

