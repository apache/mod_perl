package ModPerl::RegistryNG;

# a back-compatibility placeholder
*ModPerl::RegistryNG:: = \*ModPerl::Registry::;

# META: prototyping ($$) segfaults on request
sub handler {
    my $class = (@_ >= 2) ? shift : __PACKAGE__;
    my $r = shift;
    return $class->new($r)->default_handler();
}

1;
__END__

=head1 NAME

ModPerl::RegistryNG -- See ModPerl::Registry

=head1 SYNOPSIS

=head1 DESCRIPTION

C<ModPerl::RegistryNG> is the same as C<ModPerl::Registry>.

=cut

