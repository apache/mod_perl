package Apache::TestDirectives;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use DynaLoader (); 

use Data::Dumper 'Dumper';

@ISA = qw(DynaLoader TestDirectives::Base);

$VERSION = '0.01';

if($ENV{MOD_PERL}) {
    bootstrap Apache::TestDirectives $VERSION;
}

sub attr {
    my($self,$k,$v) = @_;
    $self->{$k} = $v;
}

sub TestCmd ($$$) {
    my($cfg, $one, $two) = @_;
    #warn "TestCmd called with args: `$one', `$two'\n";
    $cfg->attr(TestCmd => [$one,$two]);
    #warn Dumper($cfg), $/;
}

sub AnotherCmd {
    my($cfg, @data) = @_;
    $cfg->{AnotherCmd} = [@data];
    #warn Dumper($cfg), $/;
    $cfg->{YAC} = [@data];
}

sub CmdIterate ($@) {
    my($cfg, @data) = @_;
    #warn "$cfg->ITERATE: @data\n";
}

sub YAC {
    my($cfg, @data) = @_;
    #warn Dumper($cfg), $/;
}

sub Container ($$;*) {
    my($cfg, $arg) = @_;
    $arg =~ s/>//;
    warn "ARG=$arg\n";
    while(my($line) = $cfg->getline) {
	last if $line =~ m:</Container>:i;
	warn "LINE=`$line'\n";
    }
}

sub Container_END () {
    die "</Container> outside a <Container>\n";
}

use Apache::ExtUtils ();
my $proto_perl2c = Apache::ExtUtils->proto_perl2c;

my $code = "";
while(my($pp,$cp) = each %$proto_perl2c) {
    next unless $pp;
    $code .= <<SUB;
sub $cp ($pp) { 
    warn "$cp called with args: ", (map "`\$_', ", \@_), "\n";
    shift->attr($cp => [\@_]);
}
SUB
}

eval $code; die $@ if $@;

package TestDirectives::Base;

sub new {
    my $class = shift;
    return bless {FromNew => __PACKAGE__}, $class;
}

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Apache::TestDirectives - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Apache::TestDirectives;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Apache::TestDirectives was created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head1 AUTHOR

A. U. Thor, a.u.thor@a.galaxy.far.far.away

=head1 SEE ALSO

perl(1).

=cut
