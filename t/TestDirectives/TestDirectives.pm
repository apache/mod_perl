package Apache::TestDirectives;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;
require DynaLoader;
require AutoLoader;
use Data::Dumper 'Dumper';

@ISA = qw(Exporter DynaLoader);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
	
);
$VERSION = '0.01';

if($ENV{MOD_PERL}) {
    bootstrap Apache::TestDirectives $VERSION;
}

sub TestCmd ($$$) {
    my($cfg, $one, $two, $three) = @_;
    #@_ == 2 or die "prototype check failed!";
    warn "TestCmd called with args: `$one', `$two', `$three'\n";
    $cfg->{TestCmd} = [$one,$two];
    warn Dumper($cfg), $/;
    return $cfg;
}

sub AnotherCmd {
    my($cfg, @data) = @_;
    $cfg->{AnotherCmd} = [@data];
    warn Dumper($cfg), $/;
    $cfg->{YAC} = [@data];
    return $cfg;
}

sub CmdIterate (@) {
    my($cfg, @data) = @_;
    warn "$cfg->ITERATE: @data\n";
}

sub YAC {
    my($cfg, @data) = @_;
    warn Dumper($cfg), $/;
    #return $cfg;
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
