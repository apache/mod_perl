# this file is a copy of Devel::Symdump which does not ship with perl
# we use it in mod_perl to implement <Perl> sections
package ModPerl::Symdump;

use 5.003;
use Carp ();
use strict;
use vars qw($Defaults $VERSION *ENTRY);

$VERSION = '2.01';

$Defaults = {
	     'RECURS'   => 0,
	     'AUTOLOAD' => {
			    'packages'	=> 1,
			    'scalars'	=> 1,
			    'arrays'	=> 1,
			    'hashes'	=> 1,
			    'functions'	=> 1,
			    'ios'	=> 1,
			    'unknowns'	=> 1,
			   }
	    };

sub rnew {
    my($class,@packages) = @_;
    no strict "refs";
    my $self = bless {%${"$class\::Defaults"}}, $class;
    $self->{RECURS}++;
    $self->_doit(@packages);
}

sub new {
    my($class,@packages) = @_;
    no strict "refs";
    my $self = bless {%${"$class\::Defaults"}}, $class;
    $self->_doit(@packages);
}

sub _doit {
    my($self,@packages) = @_;
    @packages = ("main") unless @packages;
    $self->{RESULT} = $self->_symdump(@packages);
    return $self;
}

sub _symdump {
    my($self,@packages) = @_ ;
    my($key,$val,$num,$pack,@todo,$tmp);
    my $result = {};
    foreach $pack (@packages){
	no strict;
	while (($key,$val) = each(%{*{"$pack\::"}})) {
	    my $gotone = 0;
	    local(*ENTRY) = $val;
	    #### SCALAR ####
	    if (defined $val && defined *ENTRY{SCALAR}) {
		$result->{$pack}{SCALARS}{$key}++;
		$gotone++;
	    }
	    #### ARRAY ####
	    if (defined $val && defined *ENTRY{ARRAY}) {
		$result->{$pack}{ARRAYS}{$key}++;
		$gotone++;
	    }
	    #### HASH ####
	    if (defined $val && defined *ENTRY{HASH} && $key !~ /::/) {
		$result->{$pack}{HASHES}{$key}++;
		$gotone++;
	    }
	    #### PACKAGE ####
	    if (defined $val && defined *ENTRY{HASH} && $key =~ /::$/ &&
		    $key ne "main::")
	    {
		my($p) = $pack ne "main" ? "$pack\::" : "";
		($p .= $key) =~ s/::$//;
		$result->{$pack}{PACKAGES}{$p}++;
		$gotone++;
		push @todo, $p;
	    }
	    #### FUNCTION ####
	    if (defined $val && defined *ENTRY{CODE}) {
		$result->{$pack}{FUNCTIONS}{$key}++;
		$gotone++;
	    }

	    #### IO #### had to change after 5.003_10
	    if ($] > 5.003_10){
		if (defined $val && defined *ENTRY{IO}){ # fileno and telldir...
		    $result->{$pack}{IOS}{$key}++;
		    $gotone++;
		}
	    } else {
		#### FILEHANDLE ####
		if (defined fileno(ENTRY)){
		    $result->{$pack}{IOS}{$key}++;
		    $gotone++;
		} elsif (defined telldir(ENTRY)){
		    #### DIRHANDLE ####
		    $result->{$pack}{IOS}{$key}++;
		    $gotone++;
		}
	    }

	    #### SOMETHING ELSE ####
	    unless ($gotone) {
		$result->{$pack}{UNKNOWNS}{$key}++;
	    }
	}
    }

    return (@todo && $self->{RECURS})
		? { %$result, %{$self->_symdump(@todo)} }
		: $result;
}

sub _partdump {
    my($self,$part)=@_;
    my ($pack, @result);
    my $prepend = "";
    foreach $pack (keys %{$self->{RESULT}}){
	$prepend = "$pack\::" unless $part eq 'PACKAGES';
	push @result, map {"$prepend$_"} keys %{$self->{RESULT}{$pack}{$part} || {}};
    }
    return @result;
}

# this is needed so we don't try to AUTOLOAD the DESTROY method
sub DESTROY {}

sub as_string {
    my $self = shift;
    my($type,@m);
    for $type (sort keys %{$self->{'AUTOLOAD'}}) {
	push @m, $type;
	push @m, "\t" . join "\n\t", map {
	    s/([\000-\037\177])/ '^' . pack('c', ord($1) ^ 64) /eg;
	    $_;
	} sort $self->_partdump(uc $type);
    }
    return join "\n", @m;
}

sub as_HTML {
    my $self = shift;
    my($type,@m);
    push @m, "<TABLE>";
    for $type (sort keys %{$self->{'AUTOLOAD'}}) {
	push @m, "<TR><TD valign=top><B>$type</B></TD>";
	push @m, "<TD>" . join ", ", map {
	    s/([\000-\037\177])/ '^' .
		pack('c', ord($1) ^ 64)
		    /eg; $_;
	} sort $self->_partdump(uc $type);
	push @m, "</TD></TR>";
    }
    push @m, "</TABLE>";
    return join "\n", @m;
}

sub diff {
    my($self,$second) = @_;
    my($type,@m);
    for $type (sort keys %{$self->{'AUTOLOAD'}}) {
	my(%first,%second,%all,$symbol);
	foreach $symbol ($self->_partdump(uc $type)){
	    $first{$symbol}++;
	    $all{$symbol}++;
	}
	foreach $symbol ($second->_partdump(uc $type)){
	    $second{$symbol}++;
	    $all{$symbol}++;
	}
	my(@typediff);
	foreach $symbol (sort keys %all){
	    next if $first{$symbol} && $second{$symbol};
	    push @typediff, "- $symbol" unless $second{$symbol};
	    push @typediff, "+ $symbol" unless $first{$symbol};
	}
	foreach (@typediff) {
	    s/([\000-\037\177])/ '^' . pack('c', ord($1) ^ 64) /eg;
	}
	push @m, $type, @typediff if @typediff;
    }
    return join "\n", @m;
}

sub inh_tree {
    my($self) = @_;
    return $self->{INHTREE} if ref $self && defined $self->{INHTREE};
    my($inherited_by) = {};
    my($m)="";
    my(@isa) = grep /\bISA$/, ModPerl::Symdump->rnew->arrays;
    my $isa;
    foreach $isa (sort @isa) {
	$isa =~ s/::ISA$//;
	my($isaisa);
	no strict 'refs';
	foreach $isaisa (@{"$isa\::ISA"}){
	    $inherited_by->{$isaisa}{$isa}++;
	}
    }
    my $item;
    foreach $item (sort keys %$inherited_by) {
	$m .= "$item\n";
	$m .= _inh_tree($item,$inherited_by);
    }
    $self->{INHTREE} = $m if ref $self;
    $m;
}

sub _inh_tree {
    my($package,$href,$depth) = @_;
    return unless defined $href;
    $depth ||= 0;
    $depth++;
    if ($depth > 100){
	warn "Deep recursion in ISA\n";
	return;
    }
    my($m) = "";
    # print "DEBUG: package[$package]depth[$depth]\n";
    my $i;
    foreach $i (sort keys %{$href->{$package}}) {
	$m .= qq{\t} x $depth;
	$m .= qq{$i\n};
	$m .= _inh_tree($i,$href,$depth);
    }
    $m;
}

sub isa_tree{
    my($self) = @_;
    return $self->{ISATREE} if ref $self && defined $self->{ISATREE};
    my(@isa) = grep /\bISA$/, ModPerl::Symdump->rnew->arrays;
    my($m) = "";
    my($isa);
    foreach $isa (sort @isa) {
	$isa =~ s/::ISA$//;
	$m .= qq{$isa\n};
	$m .= _isa_tree($isa)
    }
    $self->{ISATREE} = $m if ref $self;
    $m;
}

sub _isa_tree{
    my($package,$depth) = @_;
    $depth ||= 0;
    $depth++;
    if ($depth > 100){
	warn "Deep recursion in ISA\n";
	return;
    }
    my($m) = "";
    # print "DEBUG: package[$package]depth[$depth]\n";
    my $isaisa;
    no strict 'refs';
    foreach $isaisa (@{"$package\::ISA"}) {
	$m .= qq{\t} x $depth;
	$m .= qq{$isaisa\n};
	$m .= _isa_tree($isaisa,$depth);
    }
    $m;
}

AUTOLOAD {
    my($self,@packages) = @_;
    unless (ref $self) {
	$self = $self->new(@packages);
    }
    no strict "vars";
    (my $auto = $AUTOLOAD) =~ s/.*:://;

    $auto =~ s/(file|dir)handles/ios/;
    my $compat = $1;

    unless ($self->{'AUTOLOAD'}{$auto}) {
	Carp::croak("invalid ModPerl::Symdump method: $auto()");
    }

    my @syms = $self->_partdump(uc $auto);
    if (defined $compat) {
	no strict 'refs';
	if ($compat eq "file") {
	    @syms = grep { defined(fileno($_)) } @syms;
	} else {
	    @syms = grep { defined(telldir($_)) } @syms;
	}
    }
    return @syms; # make sure now it gets context right
}

1;

__END__

=head1 NAME

ModPerl::Symdump - dump symbol names or the symbol table

=head1 SYNOPSIS

    # Constructor
    require ModPerl::Symdump;
    @packs = qw(some_package another_package);
    $obj = ModPerl::Symdump->new(@packs);        # no recursion
    $obj = ModPerl::Symdump->rnew(@packs);       # with recursion

    # Methods
    @array = $obj->packages;
    @array = $obj->scalars;
    @array = $obj->arrays;
    @array = $obj->hashs;
    @array = $obj->functions;
    @array = $obj->filehandles;  # deprecated, use ios instead
    @array = $obj->dirhandles;   # deprecated, use ios instead
    @array = $obj->ios;
    @array = $obj->unknowns;

    $string = $obj->as_string;
    $string = $obj->as_HTML;
    $string = $obj1->diff($obj2);

    $string = ModPerl::Symdump->isa_tree;    # or $obj->isa_tree
    $string = ModPerl::Symdump->inh_tree;    # or $obj->inh_tree

    # Methods with autogenerated objects
    # all of those call new(@packs) internally
    @array = ModPerl::Symdump->packages(@packs);
    @array = ModPerl::Symdump->scalars(@packs);
    @array = ModPerl::Symdump->arrays(@packs);
    @array = ModPerl::Symdump->hashes(@packs);
    @array = ModPerl::Symdump->functions(@packs);
    @array = ModPerl::Symdump->ios(@packs);
    @array = ModPerl::Symdump->unknowns(@packs);

=head2 Incompatibility with versions before 2.00

Perl 5.003 already offered the opportunity to test for the individual
slots of a GLOB with the *GLOB{XXX} notation. ModPerl::Symdump version
2.00 uses this method internally which means that the type of
undefined values is recognized in general. Previous versions
couldn't determine the type of undefined values, so the slot
I<unknowns> was invented. From version 2.00 this slot is still present
but will usually not contain any elements.

The interface has changed slightly between the perl versions 5.003 and
5.004. To be precise, from perl5.003_11 the names of the members of a
GLOB have changed. C<IO> is the internal name for all kinds of
input-output handles while C<FILEHANDLE> and C<DIRHANDLE> are
deprecated.

C<ModPerl::Symdump> accordingly introduces the new method ios() which
returns filehandles B<and> directory handles. The old methods
filehandles() and dirhandles() are still supported for a transitional
period.  They will probably have to go in future versions.

=head1 DESCRIPTION

This little package serves to access the symbol table of perl.

=over 4

=head2 C<ModPerl::Symdump-E<gt>rnew(@packages)>

returns a symbol table object for all subtrees below @packages.
Nested Modules are analyzed recursively. If no package is given as
argument, it defaults to C<main>. That means to get the whole symbol
table, just do a C<rnew> without arguments.

=head2 C<ModPerl::Symdump-E<gt>new(@packages)>

does not go into recursion and only analyzes the packages that are
given as arguments.

=back

The methods packages(), scalars(), arrays(), hashes(), functions(),
ios(), and unknowns() each return an array of fully qualified
symbols of the specified type in all packages that are held within a
ModPerl::Symdump object, but without the leading C<$>, C<@> or C<%>.  In
a scalar context, they will return the number of such symbols.
Unknown symbols are usually either formats or variables that haven't
yet got a defined value.

As_string() and as_HTML() return a simple string/HTML representations
of the object.

Diff() prints the difference between two ModPerl::Symdump objects in
human readable form. The format is similar to the one used by the
as_string method.

Isa_tree() and inh_tree() both return a simple string representation
of the current inheritance tree. The difference between the two
methods is the direction from which the tree is viewed: top-down or
bottom-up. As I'm sure, many users will have different expectation
about what is top and what is bottom, I'll provide an example what
happens when the Socket module is loaded:

=over 4

=item % print ModPerl::Symdump-E<gt>inh_tree

    AutoLoader
            DynaLoader
                    Socket
    DynaLoader
            Socket
    Exporter
            Carp
            Config
            Socket

The inh_tree method shows on the left hand side a package name and
indented to the right the packages that use the former.

=item % print ModPerl::Symdump-E<gt>isa_tree

    Carp
            Exporter
    Config
            Exporter
    DynaLoader
            AutoLoader
    Socket
            Exporter
            DynaLoader
                    AutoLoader

The isa_tree method displays from left to right ISA relationships, so
Socket IS A DynaLoader and DynaLoader IS A AutoLoader. (Actually, they
were at the time this manpage was written)

=back

You may call both methods, isa_tree() and inh_tree(), with an
object. If you do that, the object will store the output and retrieve
it when you call the same method again later. The typical usage would
be to use them as class methods directly though.

=head1 SUBCLASSING

The design of this package is intentionally primitive and allows it to
be subclassed easily. An example of a (maybe) useful subclass is
ModPerl::Symdump::Export, a package which exports all methods of the
ModPerl::Symdump package and turns them into functions.

=head1 AUTHORS

Andreas Koenig F<E<lt>andk@cpan.orgE<gt>> and Tom Christiansen
F<E<lt>tchrist@perl.comE<gt>>. Based on the old F<dumpvar.pl> by Larry
Wall.

=cut
