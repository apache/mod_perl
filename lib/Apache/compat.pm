package Apache::compat;

use strict;

#1.xx compat layer
#some of this will stay as-is
#some will be implemented proper later on

#there's enough here to get simple registry scripts working
#add to startup.pl:
#use Apache::compat ();
#use lib ...; #or something to find 1.xx Apache::Registry

#Alias /perl /path/to/perl/scripts
#<Location /perl>
#   Options +ExecCGI
#   SetHandler modperl
#   PerlResponseHandler Apache::Registry
#</Location>

use Apache::RequestRec ();
use Apache::Connection ();
use Apache::Server ();
use Apache::Access ();
use Apache::RequestIO ();
use Apache::RequestUtil ();
use Apache::Response ();
use Apache::Log ();
use Apache::URI ();
use APR::Table ();
use APR::Pool ();
use APR::URI ();
use mod_perl ();
use Symbol ();

BEGIN {
    $INC{'Apache.pm'} = __FILE__;

    $INC{'Apache/Constants.pm'} = __FILE__;

    $INC{'Apache/File.pm'} = __FILE__;
}

package Apache;

sub exit {
    require ModPerl::Util;

    my $status = 0;
    my $nargs = @_;

    if ($nargs == 2) {
        $status = $_[1];
    }
    elsif ($nargs == 1 and $_[0] =~ /^\d+$/) {
        $status = $_[0];
    }

    ModPerl::Util::exit($status);
}

#XXX: warn
sub import {
}

sub untaint {
    shift;
    require ModPerl::Util;
    ModPerl::Util::untaint(@_);
}

sub module {
    require Apache::Module;
    return Apache::Module::loaded($_[1]);
}

sub gensym {
    return Symbol::gensym();
}

package Apache::Constants;

use Apache::Const ();

sub import {
    my $class = shift;
    my $package = scalar caller;
    Apache::Const->compile($package => @_);
}

package Apache::RequestRec;

#to support $r->server_root_relative
*server_root_relative = \&Apache::server_root_relative;

#we support Apache->request; this is needed to support $r->request
#XXX: seems sorta backwards
*request = \&Apache::request;

sub table_get_set {
    my($r, $table) = (shift, shift);
    my($key, $value) = @_;

    if (1 == @_) {
        return wantarray() 
            ?       ($table->get($key))
            : scalar($table->get($key));
    }
    elsif (2 == @_) {
        if (defined $value) {
            return wantarray() 
                ?        ($table->set($key, $value))
                :  scalar($table->set($key, $value));
        }
        else {
            return wantarray() 
                ?       ($table->unset($key))
                : scalar($table->unset($key));
        }
    }
    elsif (0 == @_) {
        return $table;
    }
    else {
        my $name = (caller(1))[3];
        warn "Usage: \$r->$name([key [,val]])";
    }
}

sub header_out {
    my $r = shift;
    return wantarray() 
        ?       ($r->table_get_set(scalar($r->headers_out), @_))
        : scalar($r->table_get_set(scalar($r->headers_out), @_));
}

sub header_in {
    my $r = shift;
    return wantarray() 
        ?       ($r->table_get_set(scalar($r->headers_in), @_))
        : scalar($r->table_get_set(scalar($r->headers_in), @_));
}

sub register_cleanup {
    shift->pool->cleanup_register(@_);
}

sub parse_args {
    my($r, $string) = @_;
    return () unless defined $string and $string;

    return map {
        s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;
        $_;
    } split /[=&;]/, $string, -1;
}

#sorry, have to use $r->Apache::args at the moment
#for list context splitting

sub Apache::args {
    my $r = shift;
    my $args = $r->args;
    return $args unless wantarray;
    return $r->parse_args($args);
}

sub content {
    my $r = shift;

    $r->setup_client_block;

    return undef unless $r->should_client_block;

    my $len = $r->headers_in->get('content-length');

    my $buf;
    $r->get_client_block($buf, $len);

    return $buf unless wantarray;
    return $r->parse_args($buf)
}

sub clear_rgy_endav {
    my($r, $script_name) = @_;
    require ModPerl::Global;
    my $package = 'Apache::ROOT' . $script_name;
    ModPerl::Global::special_list_clear(END => $package);
}

sub stash_rgy_endav {
    #see run_rgy_endav
}

#if somebody really wants to have END subroutine support
#with the 1.x Apache::Registry they will need to configure:
# PerlHandler Apache::Registry Apache::compat::run_rgy_endav
sub Apache::compat::run_rgy_endav {
    my $r = shift;

    require ModPerl::Global;
    require Apache::PerlRun; #1.x's
    my $package = Apache::PerlRun->new($r)->namespace;

    ModPerl::Global::special_list_call(END => $package);
}

sub seqno {
    1;
}

sub chdir_file {
    #XXX resolve '.' in @INC to basename $r->filename
}

sub finfo {
    my $r = shift;
    stat $r->filename;
    \*_;
}

*log_reason = \&log_error;

sub slurp_filename {
    my $r = shift;
    open my $fh, $r->filename;
    local $/;
    my $data = <$fh>;
    close $fh;
    return \$data;
}

#XXX: would like to have a proper implementation
#that reads line-by-line as defined by $/
#the best way will probably be to use perlio in 5.8.0
#anything else would be more effort that it is worth
sub READLINE {
    my $r = shift;
    my $line;
    $r->read($line, $r->headers_in->get('Content-length'));
    $line ? $line : undef;
}

use constant IOBUFSIZE => 8192;

#XXX: howto convert PerlIO to apr_file_t
#so we can use the real ap_send_fd function
#2.0 ap_send_fd() also has an additional offset parameter

sub send_fd_length {
    my($r, $fh, $length) = @_;

    my $buff;
    my $total_bytes_sent = 0;
    my $len;

    return 0 if $length == 0;

    if (($length > 0) && ($total_bytes_sent + IOBUFSIZE) > $length) {
        $len = $length - $total_bytes_sent;
    }
    else {
        $len = IOBUFSIZE;
    }

    binmode $fh;

    while (CORE::read($fh, $buff, $len)) {
        $total_bytes_sent += $r->puts($buff);
    }

    $total_bytes_sent;
}

sub send_fd {
    my($r, $fh) = @_;
    $r->send_fd_length($fh, -1);
}

package Apache::File;

use Fcntl ();
use Symbol ();
use Carp ();

sub new {
    my($class) = shift;
    my $fh = Symbol::gensym;
    my $self = bless $fh, ref($class)||$class;
    if (@_) {
        return $self->open(@_) ? $self : undef;
    }
    else {
        return $self;
    }
}

sub open {
    my($self) = shift;

    Carp::croak("no Apache::File object passed")
          unless $self && ref($self);

    # cannot forward @_ to open() because of its prototype
    if (@_ > 1) {
        my ($mode, $file) = @_;
        open $self, $mode, $file;
    }
    else {
        my $file = shift;
        open $self, $file;
    }
}

sub close {
    my($self) = shift;
    close $self;
}

my $TMPNAM = 'aaaaaa';
my $TMPDIR = $ENV{'TMPDIR'} || $ENV{'TEMP'} || '/tmp';
($TMPDIR) = $TMPDIR =~ /^([^<>|;*]+)$/; #untaint
my $Mode = Fcntl::O_RDWR()|Fcntl::O_EXCL()|Fcntl::O_CREAT();
my $Perms = 0600;

sub tmpfile {
    my $class = shift;
    my $limit = 100;
    my $r = Apache->request;

    unless ($r) {
        die "cannot use Apache::File->tmpfile ",
            "without 'SetHandler perl-script' ",
            "or 'PerlOptions +GlobalRequest'";
    }

    while ($limit--) {
        my $tmpfile = "$TMPDIR/${$}" . $TMPNAM++;
        my $fh = $class->new;

        sysopen($fh, $tmpfile, $Mode, $Perms);
        $r->pool->cleanup_register(sub { unlink $tmpfile });

        if ($fh) {
            return wantarray ? ($tmpfile, $fh) : $fh;
        }
    }
}

# the following functions now live in Apache::Response
# * discard_request_body
# * meets_conditions
# * set_content_length
# * set_etag
# * set_last_modified
# * update_mtime

# the following functions now live in Apache::RequestRec
# * mtime

package Apache::Util;

sub size_string {
    my($size) = @_;

    if (!$size) {
        $size = "   0k";
    }
    elsif ($size == -1) {
        $size = "    -";
    }
    elsif ($size < 1024) {
        $size = "   1k";
    }
    elsif ($size < 1048576) {
        $size = sprintf "%4dk", ($size + 512) / 1024;
    }
    elsif ($size < 103809024) {
        $size = sprintf "%4.1fM", $size / 1048576.0;
    }
    else {
        $size = sprintf "%4dM", ($size + 524288) / 1048576;
    }

    return $size;
}

*unescape_uri = \&Apache::unescape_url;

sub Apache::URI::parse {
    my($class, $r, $uri) = @_;

    $uri ||= $r->construct_url;

    APR::URI->parse($r->pool, $uri);
}

1;
__END__
