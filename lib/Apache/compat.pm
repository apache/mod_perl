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
    $INC{'Apache.pm'} = 1;

    $INC{'Apache/Constants.pm'} = 1;

    $ENV{MOD_PERL} = $mod_perl::VERSION;
    $ENV{GATEWAY_INTERFACE} = 'CGI-Perl/1.1';
}

package Apache;

#XXX: exit,warn
sub import {
}

sub untaint {
}

package Apache::Constants;

use Apache::Const ();

sub import {
    my $class = shift;
    my $package = scalar caller;
    Apache::Const->compile($package => @_);
}

package Apache::RequestRec;

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

sub send_http_header {
    my($r, $type) = @_;
    if ($type) {
        $r->content_type($type);
    }
}

sub clear_rgy_endav {
}

sub stash_rgy_endav {
}

sub seqno {
    1;
}

sub chdir_file {
    #XXX resolve '.' in @INC to basename $r->filename
}

*print = \&puts;

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
