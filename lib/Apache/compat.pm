package Apache::compat;

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
use APR::Table ();
use APR::Pool ();
use mod_perl ();

BEGIN {
    $INC{'Apache.pm'} = __FILE__;

    $INC{'Apache/Constants.pm'} = __FILE__;
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

package Apache::Constants;

use Apache::Const ();

sub import {
    my $class = shift;
    my $package = scalar caller;
    Apache::Const->compile($package => @_);
}

package Apache::RequestRec;

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

    if (($length > 0) && ($total_bytes_send + IOBUFSIZE) > $length) {
        $len = $length - $total_bytes_sent;
    }
    else {
        $len = IOBUFSIZE;
    }

    while (read($fh, $buff, $len)) {
        $total_bytes_sent += $r->puts($buff);
    }

    $total_bytes_sent;
}

sub send_fd {
    my($r, $fh) = @_;
    $r->send_fd_length($fh, -1);
}

1;
__END__
