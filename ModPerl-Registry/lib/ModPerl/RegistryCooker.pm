# VERY IMPORTANT: Be very careful modifying the defaults, since many
# VERY IMPORTANT: packages rely on them. In fact you should never
# VERY IMPORTANT: modify the defaults after the package gets released,
# VERY IMPORTANT: since they are a hardcoded part of this suite's API.

package ModPerl::RegistryCooker;

require 5.006;

use strict;
use warnings FATAL => 'all';

# we try to develop so we reload ourselves without die'ing on the warning
no warnings qw(redefine); # XXX, this should go away in production!

our $VERSION = '1.99';

use Apache::compat ();

use Apache::Response;
use Apache::Log;
use Apache::Const -compile => qw(:common &OPT_EXECCGI);
use File::Spec::Functions ();
use ModPerl::Util ();
use ModPerl::Global ();

unless (defined $ModPerl::Registry::MarkLine) {
    $ModPerl::Registry::MarkLine = 1;
}

#########################################################################
# debug constants
#
#########################################################################
use constant D_NONE    => 0;
use constant D_ERROR   => 1;
use constant D_WARN    => 2;
use constant D_COMPILE => 4;
use constant D_NOISE   => 8;

# the debug level can be overriden on the main server level of
# httpd.conf with:
#   PerlSetVar ModPerl::RegistryCooker::DEBUG 4
use Apache::ServerUtil ();
use constant DEBUG => 0;
#XXX: below currently crashes the server on win32
#    defined Apache->server->dir_config('ModPerl::RegistryCooker::DEBUG')
#        ? Apache->server->dir_config('ModPerl::RegistryCooker::DEBUG')
#        : D_NONE;

#########################################################################
# object's array index's access constants
#
#########################################################################
use constant REQ       => 0;
use constant FILENAME  => 1;
use constant URI       => 2;
use constant MTIME     => 3;
use constant PACKAGE   => 4;
use constant CODE      => 5;
use constant STATUS    => 6;
use constant CLASS     => 7;

#########################################################################
# OS specific constants
#
#########################################################################
use constant IS_WIN32 => $^O eq "MSWin32";

#########################################################################
# constant subs
#
#########################################################################
use constant NOP   => sub {   };
use constant TRUE  => sub { 1 };
use constant FALSE => sub { 0 };


#########################################################################
# func: new
# dflt: new
# args: $class - class to bless into
#       $r     - Apache::Request object
# desc: create the class's object and bless it
# rtrn: the newly created object
#########################################################################

sub new {
    my($class, $r) = @_;
    my $o = bless [], $class;
    $o->init($r);
    return $o;
}

#########################################################################
# func: init
# dflt: init
# desc: initializes the data object's fields: CLASS REQ FILENAME URI
# args: $r - Apache::Request object
# rtrn: nothing
#########################################################################

sub init {
    $_[0]->[CLASS]    = ref $_[0];
    $_[0]->[REQ]      = $_[1];
    $_[0]->[URI]      = $_[1]->uri;
    $_[0]->[FILENAME] = $_[1]->filename;
}

#########################################################################
# func: handler
# dflt: handler
# desc: the handler() sub that is expected by Apache
# args: $class - handler's class
#       $r     - Apache::Request object
#       (o)can be called as handler($r) as well (without leading $class)
# rtrn: handler's response status
# note: must be implemented in a sub-class unless configured as
#       Apache::Foo->handler in httpd.conf (because of the
#       __PACKAGE__, which is tied to the file)
#########################################################################

sub handler {
    my $class = (@_ >= 2) ? shift : __PACKAGE__;
    my $r = shift;
    $class->new($r)->default_handler();
}

#########################################################################
# func: default_handler
# dflt: META: see above
# desc: META: see above
# args: $o - registry blessed object
# rtrn: handler's response status
# note: that's what most sub-class handlers will call
#########################################################################

sub default_handler {
    my $o = shift;

    $o->make_namespace;

    if ($o->should_compile) {
        my $rc = $o->can_compile;
        return $rc unless $rc == Apache::OK;
        $o->convert_script_to_compiled_handler;
    }

    return $o->run;
}

#########################################################################
# func: run
# dflt: run
# desc: executes the compiled code
# args: $o - registry blessed object
# rtrn: execution status (Apache::?)
#########################################################################

sub run {
    my $o = shift;

    my $r       = $o->[REQ];
    my $package = $o->[PACKAGE];

    $o->set_script_name;
    $o->chdir_file;

    my $rc = Apache::OK;
    my $cv = \&{"$package\::handler"};

    { # run the code if $r->seqno, preserve warnings setup when it's done
        no warnings;
        eval { $rc = &{$cv}($r, @_) } if $r->seqno;
        $o->[STATUS] = $rc;
        ModPerl::Global::special_list_call(END => $package);
    }

    $o->flush_namespace;

    #$o->chdir_file("$Apache::Server::CWD/");

    if ( ($rc = $o->error_check) != Apache::OK) {
        return $rc;
    }

    return Apache::OK;
}



#########################################################################
# func: can_compile
# dflt: can_compile
# desc: checks whether the script is allowed and can be compiled
# args: $o - registry blessed object
# rtrn: $rc - return status to forward
# efct: initializes the data object's fields: MTIME
#########################################################################

sub can_compile {
    my $o = shift;
    my $r = $o->[REQ];

    unless (-r $r->finfo && -s _) {
        $r->log_error("$$: $o->[FILENAME] not found or unable to stat");
	return Apache::NOT_FOUND;
    }

    return Apache::DECLINED if -d _;

    $o->[MTIME] = -M _;

    unless (-x _ or IS_WIN32) {
        $r->log_reason("file permissions deny server execution",
                       $o->[FILENAME]);
        return Apache::FORBIDDEN;
    }

    if (!($r->allow_options & Apache::OPT_EXECCGI)) {
        $r->log_reason("Options ExecCGI is off in this directory",
                       $o->[FILENAME]);
        return Apache::FORBIDDEN;
    }

    $o->debug("can compile $o->[FILENAME]") if DEBUG & D_NOISE;

    return Apache::OK;

}

#########################################################################
# func: make_namespace
# dflt: make_namespace
# desc: prepares the namespace
# args: $o - registry blessed object
# rtrn: the namespace
# efct: initializes the field: PACKAGE
#########################################################################

sub make_namespace {
    my $o = shift;

    my $package = $o->namespace_from;

    # Escape everything into valid perl identifiers
    $package =~ s/([^A-Za-z0-9_])/sprintf("_%2x", unpack("C", $1))/eg;

    # make sure that the sub-package doesn't start with a digit
    $package = "_$package";

    # prepend root
    $package = $o->[CLASS] . "::Cache::$package";

    $o->[PACKAGE] = $package;

    return $package;
}

#########################################################################
# func: namespace_from
# dflt: namespace_from_filename
# desc: returns a partial raw package name based on filename, uri, else
# args: $o - registry blessed object
# rtrn: a unique string
#########################################################################

*namespace_from = \&namespace_from_filename;

# return a package name based on $r->filename only
sub namespace_from_filename {
    my $o = shift;

    my ($volume, $dirs, $file) = 
        File::Spec::Functions::splitpath($o->[FILENAME]);
    my @dirs = File::Spec::Functions::splitdir($dirs);
    return join '_', ($volume||''), @dirs, $file;
}

# return a package name based on $r->uri only
sub namespace_from_uri {
    my $o = shift;

    my $path_info = $o->[REQ]->path_info;
    my $script_name = $path_info && $o->[URI] =~ /$path_info$/ ?
	substr($o->[URI], 0, length($o->[URI]) - length($path_info)) :
	$o->[URI];

    $script_name =~ s:/+$:/__INDEX__:;

    return $script_name;
}

#########################################################################
# func: convert_script_to_compiled_handler
# dflt: convert_script_to_compiled_handler
# desc: reads the script, converts into a handler and compiles it
# args: $o - registry blessed object
# rtrn: success/failure status
#########################################################################

sub convert_script_to_compiled_handler {
    my $o = shift;

    $o->debug("Adding package $o->[PACKAGE]") if DEBUG & D_NOISE;

    # get the script's source
    $o->read_script;

    # convert the shebang line opts into perl code
    $o->rewrite_shebang;

    # mod_cgi compat, should compile the code while in its dir, so
    # relative require/open will work.
    $o->chdir_file;

#    undef &{"$o->[PACKAGE]\::handler"}; unless DEBUG & D_NOISE; #avoid warnings
#    $o->[PACKAGE]->can('undef_functions') && $o->[PACKAGE]->undef_functions;

    my $line = $o->get_mark_line;

    $o->strip_end_data_segment;

    my $eval = join '',
                    'package ',
                    $o->[PACKAGE], ";",
                    "sub handler {\n",
                    $line,
                    ${ $o->[CODE] },
                    "\n}"; # last line comment without newline?

    my %orig_inc = %INC;

    my $rc = $o->compile(\$eval);
    $o->debug(qq{compiled package \"$o->[PACKAGE]\"}) if DEBUG & D_NOISE;

    #$o->chdir_file("$Apache::Server::CWD/");

    # %INC cleanup in case .pl files do not declare package ...;
    for (keys %INC) {
	next if $orig_inc{$_};
	next if /\.pm$/;
	delete $INC{$_};
    }

#    if(my $opt = $r->dir_config("PerlRunOnce")) {
#	$r->child_terminate if lc($opt) eq "on";
#    }

    $o->cache_it;

    return $rc;
}

#########################################################################
# func: cache_it
# dflt: cache_it
# desc: mark the package as cached by storing its modification time
# args: $o - registry blessed object
# rtrn: nothing
#########################################################################

sub cache_it {
    my $o = shift;
    no strict 'refs';
    ${ $o->[CLASS] }->{ $o->[PACKAGE] }{mtime} = $o->[MTIME];
}

#########################################################################
# func: uncache_myself
# dflt: uncache_myself
# desc: unmark the package as cached by forgetting its modification time
# args: none
# rtrn: nothing
# note: this is a function and not a method, it should be called from
#       the registry script, and using the caller() method we figure
#       out the package the script was compiled into

#########################################################################

sub uncache_myself {
    my $package = scalar caller;
    # guess the registry class from the first two package segments
    # XXX: this will break if someone creates a registry class which
    # is not X::Y, but this function was written for the tests.
    my($class) = $package =~ /([^:]+::[^:]+)/;
    warn "cannot figure out class name from $package", 
        return unless defined $class;
    no strict 'refs';
    if (exists ${$class}->{$package} && exists ${$class}->{$package}{mtime}) {
        delete ${$class}->{$package}{mtime};
    }
    else {
        warn "cannot find ${class}->{$package}{mtime}";
    }
}

#########################################################################
# func: is_cached
# dflt: is_cached
# desc: checks whether the package is already cached
# args: $o - registry blessed object
# rtrn: TRUE if cached,
#       FALSE otherwise
#########################################################################

sub is_cached {
    my $o = shift;
    no strict 'refs';
    exists ${$o->[CLASS]}->{ $o->[PACKAGE] }{mtime};
}


#########################################################################
# func: should_compile
# dflt: should_compile_once
# desc: decide whether code should be compiled or not
# args: $o - registry blessed object
# rtrn: TRUE if should compile
#       FALSE otherwise
# efct: sets MTIME if it's not set yet
#########################################################################

*should_compile = \&should_compile_once;

# return false only if the package is cached and its source file
# wasn't modified
sub should_compile_if_modified {
    my $o = shift;
    $o->[MTIME] ||= -M $o->[REQ]->finfo;
    no strict 'refs';
    !($o->is_cached && 
      ${$o->[CLASS]}->{ $o->[PACKAGE] }{mtime} <= $o->[MTIME]);
}

# return false if the package is cached already
sub should_compile_once {
    not shift->is_cached;
}

#########################################################################
# func: flush_namespace
# dflt: NOP (don't flush)
# desc: flush the compiled package's namespace
# args: $o - registry blessed object
# rtrn: nothing
#########################################################################

*flush_namespace = \&NOP;

sub flush_namespace_normal {
    my $o = shift;

    $o->debug("flushing namespace") if DEBUG & D_NOISE;

    no strict 'refs';
    my $tab = \%{ $o->[PACKAGE] . '::' };

    for (keys %$tab) {
        my $fullname = join '::', $o->[PACKAGE], $_;
        # code/hash/array/scalar might be imported make sure the gv
        # does not point elsewhere before undefing each
        if (%$fullname) {
            *{$fullname} = {};
            undef %$fullname;
        }
        if (@$fullname) {
            *{$fullname} = [];
            undef @$fullname;
        }
        if ($$fullname) {
            my $tmp; # argh, no such thing as an anonymous scalar
            *{$fullname} = \$tmp;
            undef $$fullname;
        }
        if (defined &$fullname) {
            no warnings;
            local $^W = 0;
            if (my $p = prototype $fullname) {
                *{$fullname} = eval "sub ($p) {}";
            }
            else {
                *{$fullname} = sub {};
            }
	    undef &$fullname;
	}
        if (*{$fullname}{IO}) {
            if (fileno $fullname) {
                close $fullname;
            }
        }
    }
}


#########################################################################
# func: read_script
# dflt: read_script
# desc: reads the script in
# args: $o - registry blessed object
# rtrn: nothing
# efct: initializes the CODE field with the source script
#########################################################################

# reads the contents of the file
sub read_script {
    my $o = shift;

    $o->debug("reading $o->[FILENAME]") if DEBUG & D_NOISE;
    $o->[CODE] = $o->[REQ]->slurp_filename;
}

#########################################################################
# func: rewrite_shebang
# dflt: rewrite_shebang
# desc: parse the shebang line and convert command line switches
#       (defined in %switches) into a perl code.
# args: $o - registry blessed object
# rtrn: nothing
# efct: the CODE field gets adjusted
#########################################################################

my %switches = (
   'T' => sub {
       Apache::warn("T switch is ignored, ".
		    "enable with 'PerlSwitches -T' in httpd.conf\n")
	   unless $Apache::__T; "";
   },
   'w' => sub { "use warnings;\n" },
);

sub rewrite_shebang {
    my $o = shift;
    my($line) = ${ $o->[CODE] } =~ /^(.*)$/m;
    my @cmdline = split /\s+/, $line;
    return unless @cmdline;
    return unless shift(@cmdline) =~ /^\#!/;

    my $prepend = "";
    for my $s (@cmdline) {
	next unless $s =~ s/^-//;
	last if substr($s,0,1) eq "-";
	for (split //, $s) {
	    next unless exists $switches{$_};
	    $prepend .= &{$switches{$_}};
	}
    }
    ${ $o->[CODE] } =~ s/^/$prepend/ if $prepend;
}

#########################################################################
# func: set_script_name
# dflt: set_script_name
# desc: set $0 to the script's name
# args: $o - registry blessed object
# rtrn: nothing
#########################################################################

sub set_script_name {
    *0 = \(shift->[FILENAME]);
}

#########################################################################
# func: chdir_file
# dflt: NOP
# desc: chdirs into $dir
# args: $o - registry blessed object
#       $dir - a dir 
# rtrn: nothing (?or success/failure?)
#########################################################################

*chdir_file = \&NOP;

sub chdir_file_normal {
    my($o, $dir) = @_;
    # $o->[REQ]->chdir_file($dir ? $dir : $o->[FILENAME]);
}

#########################################################################
# func: get_mark_line
# dflt: get_mark_line
# desc: generates the perl compiler #line directive
# args: $o - registry blessed object
# rtrn: returns the perl compiler #line directive
#########################################################################

sub get_mark_line {
    my $o = shift;
    # META: shouldn't this be $o->[CLASS]?
    $ModPerl::Registry::MarkLine ? "\n#line 1 $o->[FILENAME]\n" : "";
}

#########################################################################
# func: strip_end_data_segment
# dflt: strip_end_data_segment
# desc: remove the trailing non-code from $o->[CODE]
# args: $o - registry blessed object
# rtrn: nothing
#########################################################################

sub strip_end_data_segment {
    ${ +shift->[CODE] } =~ s/__(END|DATA)__(.*)//s;
}



#########################################################################
# func: compile
# dflt: compile
# desc: compile the code in $eval
# args: $o - registry blessed object
#       $eval - a ref to a scalar with the code to compile
# rtrn: success/failure
#########################################################################

sub compile {
    my($o, $eval) = @_;

    my $r = $o->[REQ];

    $o->debug("compiling $o->[FILENAME]") if DEBUG && D_COMPILE;

    ModPerl::Global::special_list_clear(END => $o->[PACKAGE]);

    ModPerl::Util::untaint($$eval);
    {
        # let the code define its own warn and strict level 
        no strict;
        no warnings FATAL => 'all'; # because we use FATAL 
        eval $$eval;
    }

    return $o->error_check;
}

#########################################################################
# func: error_check
# dflt: error_check
# desc: checks $@ for errors
# args: $o - registry blessed object
# rtrn: Apache::SERVER_ERROR if $@ is set, Apache::OK otherwise
#########################################################################

sub error_check {
    my $o = shift;
    if ($@ and substr($@,0,4) ne " at ") {
	$o->[REQ]->log_error("$$: $o->[CLASS]: `$@'");
	$@{$o->[REQ]->uri} = $@;
	#$@ = ''; #XXX fix me, if we don't do this Apache::exit() breaks	
	return Apache::SERVER_ERROR;
    }
    return Apache::OK;
}


#########################################################################
# func: install_aliases
# dflt: install_aliases
# desc: install the method aliases into $class
# args: $class - the class to install the methods into
#       $rh_aliases - a ref to a hash with aliases mapping
# rtrn: nothing
#########################################################################

sub install_aliases {
    my($class, $rh_aliases) = @_;

    no strict 'refs';
    while (my($k,$v) = each %$rh_aliases) {
        if (my $sub = *{$v}{CODE}){
            *{ $class . "::$k" } = $sub;
        }
        else {
            die "$class: $k aliasing failed; sub $v doesn't exist";
        }
    }
}

### helper methods

sub debug {
    my $o = shift;
    $o->[REQ]->log_error("$$: $o->[CLASS]: " . join '', @_);
}


1;
__END__

=head1 NAME

ModPerl::RegistryCooker - A Base Class of all mod_perl Registry Modules

=head1 SYNOPSIS


=head1 DESCRIPTION



=cut

