# Copyright 2001-2004 The Apache Software Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
package Apache::compat;

use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

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
use Apache::SubRequest ();
use Apache::Connection ();
use Apache::Server ();
use Apache::ServerUtil ();
use Apache::Access ();
use Apache::RequestIO ();
use Apache::RequestUtil ();
use Apache::Response ();
use Apache::Util ();
use Apache::Log ();
use Apache::URI ();
use APR::Date ();
use APR::Table ();
use APR::Pool ();
use APR::URI ();
use APR::Util ();
use mod_perl ();
use Symbol ();

BEGIN {
    $INC{'Apache.pm'} = __FILE__;

    $INC{'Apache/Constants.pm'} = __FILE__;

    $INC{'Apache/File.pm'} = __FILE__;

    $INC{'Apache/Table.pm'} = __FILE__;
}

# api => "overriding code"
# the overriding code, needs to "return" the original CODE reference
# when eval'ed , so that it can be restored later
my %overridable_mp2_api = (
    'Apache::RequestRec::notes' => <<'EOI',
{
    require Apache::RequestRec;
    my $orig_sub = *Apache::RequestRec::notes{CODE};
    *Apache::RequestRec::notes = sub {
        my $r = shift;
        return wantarray()
            ?       ($r->table_get_set(scalar($r->$orig_sub), @_))
            : scalar($r->table_get_set(scalar($r->$orig_sub), @_));
    };
    $orig_sub;
}
EOI

    'Apache::RequestRec::finfo' => <<'EOI',
{
    require APR::Finfo;
    my $orig_sub = *APR::Finfo::finfo{CODE};
    sub Apache::RequestRec::finfo {
        my $r = shift;
        stat $r->filename;
        \*_;
    }
    $orig_sub;
}
EOI

    'Apache::Connection::local_addr' => <<'EOI',
{
    require Apache::Connection;
    require Socket;
    require APR::SockAddr;
    my $orig_sub = *Apache::Connection::local_addr{CODE};
    *Apache::Connection::local_addr = sub {
        my $c = shift;
        Socket::pack_sockaddr_in($c->$orig_sub->port,
                                 Socket::inet_aton($c->$orig_sub->ip_get));
    };
    $orig_sub;
}
EOI

    'Apache::Connection::remote_addr' => <<'EOI',
{
    require Apache::Connection;
    require APR::SockAddr;
    require Socket;
    my $orig_sub = *Apache::Connection::remote_addr{CODE};
    *Apache::Connection::remote_addr = sub {
        my $c = shift;
        if (@_) {
            my $addr_in = shift;
            my($port, $addr) = Socket::unpack_sockaddr_in($addr_in);
            $c->$orig_sub->ip_set($addr);
            $c->$orig_sub->port_set($port);
        }
        else {
            Socket::pack_sockaddr_in($c->$orig_sub->port,
                                     Socket::inet_aton($c->$orig_sub->ip_get));
        }
    };
    $orig_sub;
}
EOI

    'APR::URI::unparse' => <<'EOI',
{
    require APR::URI;
    my $orig_sub = *APR::URI::unparse{CODE};
    *APR::URI::unparse = sub {
        my($uri, $flags) = @_;

        if (defined $uri->hostname && !defined $uri->scheme) {
            # we do this only for back compat, the new APR::URI is
            # protocol-agnostic and doesn't fallback to 'http' when the
            # scheme is not provided
            $uri->scheme('http');
        }

        $orig_sub->(@_);
    };
    $orig_sub;
}
EOI

    'Apache::server_root_relative' => <<'EOI',
{
    require Apache::Server;
    require Apache::ServerUtil;

    my $orig_sub = *Apache::Server::server_root_relative{CODE};
    *Apache::server_root_relative = sub {
        my $class = shift;
        return Apache->server->server_root_relative(@_);
    };
    $orig_sub;
}

EOI

    'Apache::Util::ht_time' => <<'EOI',
{
    require Apache::Util;
    my $orig_sub = *Apache::Util::ht_time{CODE};
    *Apache::Util::ht_time = sub {
        my $r = Apache::compat::request('Apache::Util::ht_time');
        return $orig_sub->($r->pool, @_);
    };
    $orig_sub;
}

EOI

);

my %overridden_mp2_api = ();

# this function enables back-compatible APIs which can't coexist with
# mod_perl 2.0 APIs with the same name and therefore it should be
# avoided if possible.
#
# it expects a list of fully qualified functions, like
# "Apache::RequestRec::finfo"
sub override_mp2_api {
    my (@subs) = @_;

    for my $sub (@subs) {
        unless (exists $overridable_mp2_api{$sub}) {
            die __PACKAGE__ . ": $sub is not overridable";
        }
        if (exists $overridden_mp2_api{$sub}) {
            warn __PACKAGE__ . ": $sub has been already overridden";
            next;
        }
        $overridden_mp2_api{$sub} = eval $overridable_mp2_api{$sub};
        unless (exists $overridden_mp2_api{$sub} &&
                ref($overridden_mp2_api{$sub}) eq 'CODE') {
            die "overriding $sub didn't return a CODE ref";
        }
    }
}

# restore_mp2_api does the opposite of override_mp2_api(), it removes
# the overriden API and restores the original mod_perl 2.0 API
sub restore_mp2_api {
    my (@subs) = @_;

    for my $sub (@subs) {
        unless (exists $overridable_mp2_api{$sub}) {
            die __PACKAGE__ . ": $sub is not overridable";
        }
        unless (exists $overridden_mp2_api{$sub}) {
            warn __PACKAGE__ . ": can't restore $sub, " .
                "as it has not been overridden";
            next;
        }
        # XXX: 5.8.2+ can't delete and assign at once - gives:
        #    Attempt to free unreferenced scalar
        # after perl_clone. the 2 step works ok. to reproduce:
        # t/TEST -maxclients 1 perl/ithreads2.t compat/request.t
        my $original_sub = $overridden_mp2_api{$sub};
        delete $overridden_mp2_api{$sub};
        no warnings 'redefine';
        no strict 'refs';
        *$sub = $original_sub;
    }
}

sub request {
    my $what = shift;

    my $r = Apache->request;

    unless ($r) {
        die "cannot use $what ",
            "without 'SetHandler perl-script' ",
            "or 'PerlOptions +GlobalRequest'";
    }

    $r;
}

package Apache::Server;
# XXX: is that good enough? see modperl/src/modules/perl/mod_perl.c:367
our $CWD = Apache::server_root;

our $AddPerlVersion = 1;

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
    die 'Usage: Apache->module($name)' if @_ != 2;
    return Apache::Module::loaded($_[1]);
}

sub gensym {
    return Symbol::gensym();
}

sub define {
    shift if @_ == 2;
    exists_config_define(@_);
}

sub log_error {
    Apache->server->log_error(@_);
}

sub httpd_conf {
    shift;
    my $obj;
    eval { $obj = Apache->request };
    $obj = Apache->server if $@;
    my $err = $obj->add_config([split /\n/, join '', @_]);
    die $err if $err;
}

# mp2 always can stack handlers
sub can_stack_handlers { 1; }

sub push_handlers {
    shift;
    Apache->server->push_handlers(@_);
}

sub set_handlers {
    shift;
    Apache->server->set_handlers(@_);
}

sub get_handlers {
    shift;
    Apache->server->get_handlers(@_);
}

package Apache::Constants;

use Apache::Const ();

sub import {
    my $class = shift;
    my $package = scalar caller;

    my @args = @_;

    # treat :response as :common - it's not perfect
    # but simple and close enough for the majority
    my %args = map { s/^:response$/:common/; $_ => 1 } @args;

    Apache::Const->compile($package => keys %args);
}

#no need to support in 2.0
sub export {}

sub SERVER_VERSION { Apache::get_server_version() }

package Apache::RequestRec;

use Apache::Const -compile => qw(REMOTE_NAME);

#no longer exist in 2.0
sub soft_timeout {}
sub hard_timeout {}
sub kill_timeout {}
sub reset_timeout {}

# this function is from mp1's Apache::SubProcess 3rd party module
# which is now a part of mp2 API. this function doesn't exist in 2.0.
sub cleanup_for_exec {}

sub current_callback {
    return Apache::current_callback();
}

sub send_http_header {
    my ($r, $type) = @_;

    # since send_http_header() in mp1 was telling mod_perl not to
    # parse headers and in mp2 one must call $r->content_type($type) to
    # perform the same, we make sure that this happens
    $type = $r->content_type || 'text/html' unless defined $type;

    $r->content_type($type);
}

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

sub err_header_out {
    my $r = shift;
    return wantarray() 
        ?       ($r->table_get_set(scalar($r->err_headers_out), @_))
        : scalar($r->table_get_set(scalar($r->err_headers_out), @_));
}


sub register_cleanup {
    shift->pool->cleanup_register(@_);
}

*post_connection = \&register_cleanup;

sub get_remote_host {
    my($r, $type) = @_;
    $type = Apache::REMOTE_NAME unless defined $type;
    $r->connection->get_remote_host($type, $r->per_dir_config);
}

#XXX: should port 1.x's Apache::URI::unescape_url_info
sub parse_args {
    my($r, $string) = @_;
    return () unless defined $string and $string;

    return map {
        tr/+/ /;
        s/%([0-9a-fA-F]{2})/pack("C",hex($1))/ge;
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

use constant IOBUFSIZE => 8192;

sub content {
    my $r = shift;

    $r->setup_client_block;

    return undef unless $r->should_client_block;

    my $data = '';
    my $buf;
    while (my $read_len = $r->get_client_block($buf, IOBUFSIZE)) {
        if ($read_len == -1) {
            die "some error while reading with get_client_block";
        }
        $data .= $buf;
    }

    return $data unless wantarray;
    return $r->parse_args($data);
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

*log_reason = \&log_error;

#XXX: would like to have a proper implementation
#that reads line-by-line as defined by $/
#the best way will probably be to use perlio in 5.8.0
#anything else would be more effort than it is worth
sub READLINE {
    my $r = shift;
    my $line;
    $r->read($line, $r->headers_in->get('Content-length'));
    $line ? $line : undef;
}

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

sub is_main { !shift->main }

# really old back-compat methods, they shouldn't be used in mp1
*cgi_var = *cgi_env = \&Apache::RequestRec::subprocess_env;

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
        CORE::open $self, $mode, $file;
    }
    else {
        my $file = shift;
        CORE::open $self, $file;
    }
}

sub close {
    my($self) = shift;
    CORE::close $self;
}

my $TMPNAM = 'aaaaaa';
my $TMPDIR = $ENV{'TMPDIR'} || $ENV{'TEMP'} || '/tmp';
($TMPDIR) = $TMPDIR =~ /^([^<>|;*]+)$/; #untaint
my $Mode = Fcntl::O_RDWR()|Fcntl::O_EXCL()|Fcntl::O_CREAT();
my $Perms = 0600;

sub tmpfile {
    my $class = shift;
    my $limit = 100;
    my $r = Apache::compat::request('Apache::File->tmpfile');

    while ($limit--) {
        my $tmpfile = "$TMPDIR/${$}" . $TMPNAM++;
        my $fh = $class->new;

        sysopen $fh, $tmpfile, $Mode, $Perms
            or die "failed to open $tmpfile: $!";
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

*unescape_uri = \&Apache::URI::unescape_url;

sub escape_uri {
    my $path = shift;
    my $r = Apache::compat::request('Apache::Util::escape_uri');
    Apache::Util::escape_path($path, $r->pool);
}

#tmp compat until ap_escape_html is reworked to not require a pool
my %html_escapes = (
    '<' => 'lt',
    '>' => 'gt',
    '&' => 'amp',
    '"' => 'quot',
);

%html_escapes = map { $_, "&$html_escapes{$_};" } keys %html_escapes;

my $html_escape = join '|', keys %html_escapes;

sub escape_html {
    my $html = shift;
    $html =~ s/($html_escape)/$html_escapes{$1}/go;
    $html;
}

*parsedate = \&APR::Date::parse_http;

*validate_password = \&APR::password_validate;

sub Apache::URI::parse {
    my($class, $r, $uri) = @_;

    $uri ||= $r->construct_url;

    APR::URI->parse($r->pool, $uri);
}

package Apache::Table;

sub new {
    my($class, $r, $nelts) = @_;
    $nelts ||= 10;
    APR::Table::make($r->pool, $nelts);
}

package Apache::SIG;

use Apache::Const -compile => 'DECLINED';

sub handler {
    # don't set the SIGPIPE
    return Apache::DECLINED;
}

package Apache::Connection;

# auth_type and user records don't exist in 2.0 conn_rec struct
# 'PerlOptions +GlobalRequest' is required
sub auth_type { shift; Apache->request->ap_auth_type(@_) }
sub user      { shift; Apache->request->user(@_)      }

1;
__END__
