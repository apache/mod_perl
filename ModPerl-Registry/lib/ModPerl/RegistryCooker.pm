# VERY IMPORTANT: Be very careful modifying the defaults, since many
# VERY IMPORTANT: packages rely on them. In fact you should never
# VERY IMPORTANT: modify the defaults after the package gets released,
# VERY IMPORTANT: since they are a hardcoded part of this suite's API.

package ModPerl::RegistryCooker;

require 5.006;

use strict;
use warnings FATAL => 'all';

our $VERSION = '1.99';

use Apache::Response ();
use Apache::RequestRec ();
use Apache::RequestUtil ();
use Apache::RequestIO ();
use Apache::Log ();
use Apache::Access ();

use APR::Table ();

use ModPerl::Util ();
use ModPerl::Global ();

use File::Spec::Functions ();

use Apache::Const -compile => qw(:common &OPT_EXECCGI);

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
# OS specific constants
#
#########################################################################
use constant IS_WIN32 => $^O eq "MSWin32";

#########################################################################
# constant subs
#
#########################################################################
use constant NOP   => '';
use constant TRUE  => 1;
use constant FALSE => 0;


use constant NAMESPACE_ROOT => 'ModPerl::ROOT';


#########################################################################

unless (defined $ModPerl::RegistryCooker::NameWithVirtualHost) {
    $ModPerl::RegistryCooker::NameWithVirtualHost = 1;
}

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
    my $self = bless {}, $class;
    $self->init($r);
    return $self;
}

#########################################################################
# func: init
# dflt: init
# desc: initializes the data object's fields: REQ FILENAME URI
# args: $r - Apache::Request object
# rtrn: nothing
#########################################################################

sub init {
    $_[0]->{REQ}      = $_[1];
    $_[0]->{URI}      = $_[1]->uri;
    $_[0]->{FILENAME} = $_[1]->filename;
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

sub handler : method {
    my $class = (@_ >= 2) ? shift : __PACKAGE__;
    my $r = shift;
    return $class->new($r)->default_handler();
}

#########################################################################
# func: default_handler
# dflt: META: see above
# desc: META: see above
# args: $self - registry blessed object
# rtrn: handler's response status
# note: that's what most sub-class handlers will call
#########################################################################

sub default_handler {
    my $self = shift;

    $self->make_namespace;

    if ($self->should_compile) {
        my $rc = $self->can_compile;
        return $rc unless $rc == Apache::OK;
        $rc = $self->convert_script_to_compiled_handler;
        return $rc unless $rc == Apache::OK;
    }

    # handlers shouldn't set $r->status but return it, so we reset the
    # status after running it
    my $old_status = $self->{REQ}->status;
    my $rc = $self->run;
    my $new_status = $self->{REQ}->status($old_status);
    return ($rc == Apache::OK && $old_status != $new_status)
        ? $new_status
        : $rc;
}

#########################################################################
# func: run
# dflt: run
# desc: executes the compiled code
# args: $self - registry blessed object
# rtrn: execution status (Apache::?)
#########################################################################

sub run {
    my $self = shift;

    my $r       = $self->{REQ};
    my $package = $self->{PACKAGE};

    $self->chdir_file;

    my $cv = \&{"$package\::handler"};

    my %orig_inc;
    if ($self->should_reset_inc_hash) {
        %orig_inc = %INC;
    }

    { # run the code and preserve warnings setup when it's done
        no warnings;
        eval { $cv->($r, @_) };
        ModPerl::Global::special_list_call(END => $package);
    }

    if ($self->should_reset_inc_hash) {
        # to avoid the bite of require'ing a file with no package delaration
        # Apache::PerlRun in mod_perl 1.15_01 started to localize %INC
        # later on it has been adjusted to preserve loaded .pm files,
        # which presumably contained the package declaration
        for (keys %INC) {
            next if $orig_inc{$_};
            next if /\.pm$/;
            delete $INC{$_};
        }
    }

    $self->flush_namespace;

    #XXX: $self->chdir_file("$Apache::Server::CWD/");

    if ( (my $err_rc = $self->error_check) != Apache::OK) {
        return $err_rc;
    }

    return Apache::OK;
}



#########################################################################
# func: can_compile
# dflt: can_compile
# desc: checks whether the script is allowed and can be compiled
# args: $self - registry blessed object
# rtrn: $rc - return status to forward
# efct: initializes the data object's fields: MTIME
#########################################################################

sub can_compile {
    my $self = shift;
    my $r = $self->{REQ};

    unless (-r $r->my_finfo && -s _) {
        $self->log_error("$self->{FILENAME} not found or unable to stat");
        return Apache::NOT_FOUND;
    }

    return Apache::DECLINED if -d _;

    $self->{MTIME} = -M _;

    unless (-x _ or IS_WIN32) {
        $r->log_error("file permissions deny server execution",
                       $self->{FILENAME});
        return Apache::FORBIDDEN;
    }

    if (!($r->allow_options & Apache::OPT_EXECCGI)) {
        $r->log_error("Options ExecCGI is off in this directory",
                       $self->{FILENAME});
        return Apache::FORBIDDEN;
    }

    $self->debug("can compile $self->{FILENAME}") if DEBUG & D_NOISE;

    return Apache::OK;

}
#########################################################################
# func: namespace_root
# dflt: namespace_root
# desc: define the namespace root for storing compiled scripts
# args: $self - registry blessed object
# rtrn: the namespace root
#########################################################################

sub namespace_root {
    my $self = shift;
    join '::', NAMESPACE_ROOT, ref($self);
}

#########################################################################
# func: make_namespace
# dflt: make_namespace
# desc: prepares the namespace
# args: $self - registry blessed object
# rtrn: the namespace
# efct: initializes the field: PACKAGE
#########################################################################

sub make_namespace {
    my $self = shift;

    my $package = $self->namespace_from;

    # Escape everything into valid perl identifiers
    $package =~ s/([^A-Za-z0-9_])/sprintf("_%2x", unpack("C", $1))/eg;

    # make sure that the sub-package doesn't start with a digit
    $package =~ s/^(\d)/_$1/;

    # prepend root
    $package = $self->namespace_root() . "::$package";

    $self->{PACKAGE} = $package;

    return $package;
}

#########################################################################
# func: namespace_from
# dflt: namespace_from_filename
# desc: returns a partial raw package name based on filename, uri, else
# args: $self - registry blessed object
# rtrn: a unique string
#########################################################################

*namespace_from = \&namespace_from_filename;

# return a package name based on $r->filename only
sub namespace_from_filename {
    my $self = shift;

    my ($volume, $dirs, $file) = 
        File::Spec::Functions::splitpath($self->{FILENAME});
    my @dirs = File::Spec::Functions::splitdir($dirs);
    return join '_', grep { defined && length } $volume, @dirs, $file;
}

# return a package name based on $r->uri only
sub namespace_from_uri {
    my $self = shift;

    my $path_info = $self->{REQ}->path_info;
    my $script_name = $path_info && $self->{URI} =~ /$path_info$/
        ? substr($self->{URI}, 0, length($self->{URI}) - length($path_info))
        : $self->{URI};

    if ($ModPerl::RegistryCooker::NameWithVirtualHost && 
        $self->{REQ}->server->is_virtual) {
        my $name = $self->{REQ}->get_server_name;
        $script_name = join "", $name, $script_name if $name;
    }

    $script_name =~ s:/+$:/__INDEX__:;

    return $script_name;
}

#########################################################################
# func: convert_script_to_compiled_handler
# dflt: convert_script_to_compiled_handler
# desc: reads the script, converts into a handler and compiles it
# args: $self - registry blessed object
# rtrn: success/failure status
#########################################################################

sub convert_script_to_compiled_handler {
    my $self = shift;

    $self->debug("Adding package $self->{PACKAGE}") if DEBUG & D_NOISE;

    # get the script's source
    $self->read_script;

    # convert the shebang line opts into perl code
    $self->rewrite_shebang;

    # mod_cgi compat, should compile the code while in its dir, so
    # relative require/open will work.
    $self->chdir_file;

#    undef &{"$self->{PACKAGE}\::handler"}; unless DEBUG & D_NOISE; #avoid warnings
#    $self->{PACKAGE}->can('undef_functions') && $self->{PACKAGE}->undef_functions;

    my $line = $self->get_mark_line;

    $self->strip_end_data_segment;

    my $script_name = $self->get_script_name || $0;

    my $eval = join '',
                    'package ',
                    $self->{PACKAGE}, ";",
                    "sub handler {",
                    "local \$0 = '$script_name';",
                    $line,
                    ${ $self->{CODE} },
                    "\n}"; # last line comment without newline?

    my $rc = $self->compile(\$eval);
    return $rc unless $rc == Apache::OK;
    $self->debug(qq{compiled package \"$self->{PACKAGE}\"}) if DEBUG & D_NOISE;

    #$self->chdir_file("$Apache::Server::CWD/");

#    if(my $opt = $r->dir_config("PerlRunOnce")) {
#        $r->child_terminate if lc($opt) eq "on";
#    }

    $self->cache_it;

    return $rc;
}

#########################################################################
# func: cache_table
# dflt: cache_table_common
# desc: return a symbol table for caching compiled scripts in
# args: $self - registry blessed object (or the class name)
# rtrn: symbol table
#########################################################################

*cache_table = \&cache_table_common;

sub cache_table_common {
    \%ModPerl::RegistryCache;
}


sub cache_table_local {
    my $self = shift;
    my $class = ref($self) || $self;
    no strict 'refs';
    \%$class;
}

#########################################################################
# func: cache_it
# dflt: cache_it
# desc: mark the package as cached by storing its modification time
# args: $self - registry blessed object
# rtrn: nothing
#########################################################################

sub cache_it {
    my $self = shift;
    $self->cache_table->{ $self->{PACKAGE} }{mtime} = $self->{MTIME};
}


#########################################################################
# func: is_cached
# dflt: is_cached
# desc: checks whether the package is already cached
# args: $self - registry blessed object
# rtrn: TRUE if cached,
#       FALSE otherwise
#########################################################################

sub is_cached {
    my $self = shift;
    exists $self->cache_table->{ $self->{PACKAGE} }{mtime};
}


#########################################################################
# func: should_compile
# dflt: should_compile_once
# desc: decide whether code should be compiled or not
# args: $self - registry blessed object
# rtrn: TRUE if should compile
#       FALSE otherwise
# efct: sets MTIME if it's not set yet
#########################################################################

*should_compile = \&should_compile_once;

# return false only if the package is cached and its source file
# wasn't modified
sub should_compile_if_modified {
    my $self = shift;
    $self->{MTIME} ||= -M $self->{REQ}->my_finfo;
    !($self->is_cached && 
      $self->cache_table->{ $self->{PACKAGE} }{mtime} <= $self->{MTIME});
}

# return false if the package is cached already
sub should_compile_once {
    not shift->is_cached;
}

#########################################################################
# func: should_reset_inc_hash
# dflt: FALSE
# desc: decide whether to localize %INC for required .pl files from the script
# args: $self - registry blessed object
# rtrn: TRUE if should reset
#       FALSE otherwise
#########################################################################

*should_reset_inc_hash = \&FALSE;

#########################################################################
# func: flush_namespace
# dflt: NOP (don't flush)
# desc: flush the compiled package's namespace
# args: $self - registry blessed object
# rtrn: nothing
#########################################################################

*flush_namespace = \&NOP;

sub flush_namespace_normal {
    my $self = shift;

    $self->debug("flushing namespace") if DEBUG & D_NOISE;

    no strict 'refs';
    my $tab = \%{ $self->{PACKAGE} . '::' };

    for (keys %$tab) {
        my $fullname = join '::', $self->{PACKAGE}, $_;
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
            if (defined(my $p = prototype $fullname)) {
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
# args: $self - registry blessed object
# rtrn: nothing
# efct: initializes the CODE field with the source script
#########################################################################

# reads the contents of the file
sub read_script {
    my $self = shift;

    $self->debug("reading $self->{FILENAME}") if DEBUG & D_NOISE;
    $self->{CODE} = $self->{REQ}->slurp_filename(0); # untainted
}

#########################################################################
# func: rewrite_shebang
# dflt: rewrite_shebang
# desc: parse the shebang line and convert command line switches
#       (defined in %switches) into a perl code.
# args: $self - registry blessed object
# rtrn: nothing
# efct: the CODE field gets adjusted
#########################################################################

my %switches = (
   'T' => sub {
       Apache::warn("-T switch is ignored, " .
                    "enable with 'PerlSwitches -T' in httpd.conf\n")
             unless ${^TAINT};
       "";
   },
   'w' => sub { "use warnings;\n" },
);

sub rewrite_shebang {
    my $self = shift;
    my($line) = ${ $self->{CODE} } =~ /^(.*)$/m;
    my @cmdline = split /\s+/, $line;
    return unless @cmdline;
    return unless shift(@cmdline) =~ /^\#!/;

    my $prepend = "";
    for my $s (@cmdline) {
        next unless $s =~ s/^-//;
        last if substr($s,0,1) eq "-";
        for (split //, $s) {
            next unless exists $switches{$_};
            $prepend .= $switches{$_}->();
        }
    }
    ${ $self->{CODE} } =~ s/^/$prepend/ if $prepend;
}

#########################################################################
# func: get_script_name
# dflt: get_script_name
# desc: get the script's name to set into $0
# args: $self - registry blessed object
# rtrn: path to the script's filename
#########################################################################

sub get_script_name {
    shift->{FILENAME};
}

#########################################################################
# func: chdir_file
# dflt: NOP
# desc: chdirs into $dir
# args: $self - registry blessed object
#       $dir - a dir 
# rtrn: nothing (?or success/failure?)
#########################################################################

*chdir_file = \&NOP;

sub chdir_file_normal {
    my($self, $dir) = @_;
    # $self->{REQ}->chdir_file($dir ? $dir : $self->{FILENAME});
}

#########################################################################
# func: get_mark_line
# dflt: get_mark_line
# desc: generates the perl compiler #line directive
# args: $self - registry blessed object
# rtrn: returns the perl compiler #line directive
#########################################################################

sub get_mark_line {
    my $self = shift;
    $ModPerl::Registry::MarkLine ? "\n#line 1 $self->{FILENAME}\n" : "";
}

#########################################################################
# func: strip_end_data_segment
# dflt: strip_end_data_segment
# desc: remove the trailing non-code from $self->{CODE}
# args: $self - registry blessed object
# rtrn: nothing
#########################################################################

sub strip_end_data_segment {
    ${ +shift->{CODE} } =~ s/__(END|DATA)__(.*)//s;
}



#########################################################################
# func: compile
# dflt: compile
# desc: compile the code in $eval
# args: $self - registry blessed object
#       $eval - a ref to a scalar with the code to compile
# rtrn: success/failure
# note: $r must not be in scope of compile(), scripts must do
#       my $r = shift; to get it off the args stack
#########################################################################

sub compile {
    my($self, $eval) = @_;

    $self->debug("compiling $self->{FILENAME}") if DEBUG && D_COMPILE;

    ModPerl::Global::special_list_clear(END => $self->{PACKAGE});

    {
        # let the code define its own warn and strict level 
        no strict;
        no warnings FATAL => 'all'; # because we use FATAL 
        eval $$eval;
    }

    return $self->error_check;
}

#########################################################################
# func: error_check
# dflt: error_check
# desc: checks $@ for errors
# args: $self - registry blessed object
# rtrn: Apache::SERVER_ERROR if $@ is set, Apache::OK otherwise
#########################################################################

sub error_check {
    my $self = shift;
    if ($@ and substr($@,0,4) ne " at ") {
        $self->log_error($@);
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
    my $self = shift;
    my $class = ref $self;
    $self->{REQ}->log_error("$$: $class: " . join '', @_);
}

sub log_error {
    my($self, $msg) = @_;
    my $class = ref $self;

    $self->{REQ}->log_error("$$: $class: $msg");
    $self->{REQ}->notes->set('error-notes' => $msg);
    $@{$self->{URI}} = $msg;
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

# this is a function should be called from the registry script, and
# using the caller() method we figure out the package the script was
# compiled into and trying to uncache it.
#
# it's currently used only for testing purposes and not a part of the
# public interface. it expects to find the compiled package in the
# symbol table cache returned by cache_table_common(), if you override
# cache_table() to point to another function, this function will fail.
sub uncache_myself {
    my $package = scalar caller;
    my($class) = __PACKAGE__->cache_table_common();

    unless (defined $class) {
        Apache->warn("$$: cannot figure out cache symbol table for $package");
        return;
    }

    if (exists $class->{$package} && exists $class->{$package}{mtime}) {
        Apache->warn("$$: uncaching $package\n") if DEBUG & D_COMPILE;
        delete $class->{$package}{mtime};
    }
    else {
        Apache->warn("$$: cannot find $package in cache");
    }
}


# XXX: should go away when finfo() is ported to 2.0 (don't want to
# depend on compat.pm)
sub Apache::RequestRec::my_finfo {
    my $r = shift;
    stat $r->filename;
    \*_;
}


1;
__END__
