package ModPerl::ParseSource;

use strict;
use Config ();
use Apache::ParseSource ();

our @ISA = qw(Apache::ParseSource);
our $VERSION = '0.01';

sub includes {
    my $self = shift;
    my $dirs = $self->SUPER::includes;
    return [
            '.', qw(xs src/modules/perl),
            @$dirs,
            "$Config::Config{archlibexp}/CORE",
           ];
}

sub include_dirs { '.' }

sub find_includes {
    my $self = shift;
    my $includes = $self->SUPER::find_includes;
    #filter/sort
    my @wanted  = grep { /mod_perl\.h/ } @$includes;
    push @wanted, grep { m:xs/modperl_xs_: } @$includes;
    push @wanted, grep { m:xs/[AM]: } @$includes;
    \@wanted;
}

my $prefixes = join '|', qw(modperl mpxs mp_xs);
my $prefix_re = qr{^($prefixes)_};
sub wanted_functions { $prefix_re }

sub write_functions_pm {
    my $self = shift;
    my $file = shift || 'FunctionTable.pm';
    my $name = shift || 'ModPerl::FunctionTable';
    $self->SUPER::write_functions_pm($file, $name);
}

for my $method (qw(get_constants get_structs write_structs_pm get_structs)) {
    no strict 'refs';
    *$method = sub { die __PACKAGE__ . "->$method not implemented" };
}

1;
__END__
