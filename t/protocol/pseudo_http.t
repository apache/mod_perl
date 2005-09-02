use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest ();

my $module = 'TestProtocol::pseudo_http';

{
    # debug
    Apache::TestRequest::module($module);
    my $hostport = Apache::TestRequest::hostport(Apache::Test::config());
    t_debug("connecting to $hostport");
}

my $login    = "stas";
my $passgood = "foobar";
my $passbad  = "foObaR";

# blocking socket bug fixed in 2.0.52
my $ok = $^O !~ /^(Open|Net)BSD$/i || need_min_apache_version('2.0.52');

# but not in 2.1?  hmph.
$ok = skip_reason('skipping on httpd 2.1') if have_min_apache_version('2.1');

plan tests => 13, need need_auth, need_access, $ok;

{
    # supply correct credential when prompted for such and ask the
    # server get the secret datetime information
    my $socket = Apache::TestRequest::vhost_socket($module);
    ok $socket;

    expect_reply($socket, "HELO",      "HELO",    "greeting");
    expect_reply($socket, "Login:",    $login,    "login");
    expect_reply($socket, "Password:", $passgood, "good password");
    expect($socket, "Welcome to TestProtocol::pseudo_http", "banner");
    expect_reply($socket, "Available commands: date quit", "date", "date");
    expect_reply($socket, qr/The time is:/,        "quit", "quit");
    expect($socket, "Goodbye", "end of transmission");
}

{
    # this time sending wrong credentials and hoping that the server
    # won't let us in
    my $socket = Apache::TestRequest::vhost_socket($module);
    ok $socket;

    expect_reply($socket, "HELO",      "HELO",   "greeting");
    expect_reply($socket, "Login:",    $login,   "login");
    t_client_log_error_is_expected();
    expect_reply($socket, "Password:", $passbad, "wrong password");
    expect($socket, "Access Denied", "end of transmission");
}

sub expect {
    my ($socket, $expect, $action) = @_;
    chomp(my $recv = <$socket> || '');
    ok t_cmp($recv, $expect, $action);
}

sub expect_reply {
    my ($socket, $expect, $reply, $action) = @_;
    chomp(my $recv = <$socket> || '');
    ok t_cmp($recv, $expect, $action);
    t_debug("send: $reply");
    print $socket $reply;
}

