package Apache::TestDirectives;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use DynaLoader (); 
use Apache::Constants ();
*DECLINE_CMD = \&Apache::Constants::DECLINE_CMD;

eval {
  require Apache::ModuleConfig;
};
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

sub Port ($$$) {
    my($parms, $cfg, $port) = @_;
    warn "Port will be $port\n";
    return DECLINE_CMD();
}

sub TestCmd ($$$$) {
    my($parms, $cfg, $one, $two) = @_;
    #warn "TestCmd called with args: `$one', `$two'\n";
    $cfg->attr(TestCmd => [$one,$two]);
    $parms->server->isa("Apache::Server") or die "parms->server busted";
    my $or = $parms->override;
    my $limit = $parms->limited;
    #warn Dumper($cfg), $/;
}

sub AnotherCmd () {
    die "prototype check broken [@_]" if @_ > 0;
}

sub CmdIterate ($$@) {
    my($parms, $cfg, @data) = @_;
    $cfg->{CmdIterate} = [@data];
    $cfg->{path} = $parms->path;
}

sub another_cmd {
    my($parms, $cfg, @data) = @_;
    $parms->info =~ /YAC/ or die "parms->info busted";
    $cfg->{parms_info_from_another_cmd} = $parms->info;
}

sub Container ($$$;*) {
    my($parms, $cfg, $arg, $fh) = @_;
    $arg =~ s/>//;
    warn "ARG=$arg\n";
    #while($parms->getline($line)) {
    while(defined(my $line = <$fh>)) {
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
    my(\$parms, \$cfg, \@args) = \@_;
    \$cfg->attr($cp => [\@args]) if ref(\$cfg);
}
SUB
}

eval $code; die $@ if $@;

package TestDirectives::Base;

sub new {
    my($class, $parms) = @_;
    return bless {
	FromNew => __PACKAGE__,
	path => $parms->path || "",
    }, $class;
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
