use Socket (); #test DynaLoader vs. XSLoader workaround for 5.6.x
use IO::File ();
use File::Spec::Functions qw(canonpath catdir);

use Apache2 ();

use Apache::Server ();
use Apache::ServerUtil ();
use Apache::Process ();

# after Apache2 has pushed blib and core dirs including Apache2 on top
# reorg @INC to have first devel libs, then blib libs, and only then
# perl core libs
my $pool = Apache->server->process->pool;
my $project_root = canonpath Apache::Server::server_root_relative($pool, "..");
my (@a, @b, @c);
for (@INC) {
    if (m|^\Q$project_root\E|) {
        m|blib| ? push @b, $_ : push @a, $_;
    }
    else {
        push @c, $_;
    }
}
@INC = (@a, @b, @c);

use ModPerl::Util (); #for CORE::GLOBAL::exit

use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::RequestUtil ();

use Apache::Connection ();
use Apache::Log ();

use Apache::Const -compile => ':common';
use APR::Const -compile => ':common';

use APR::Table ();

unless ($ENV{MOD_PERL}) {
    die '$ENV{MOD_PERL} not set!';
}

#see t/modperl/methodobj
use TestModperl::methodobj ();
$TestModperl::MethodObj = TestModperl::methodobj->new;

#see t/response/TestModperl/env.pm
$ENV{MODPERL_EXTRA_PL} = __FILE__;

my $ap_mods = scalar grep { /^Apache/ } keys %INC;
my $apr_mods = scalar grep { /^APR/ } keys %INC;

Apache::Log->info("$ap_mods Apache:: modules loaded");
Apache::Server->log->info("$apr_mods APR:: modules loaded");

{
    my $server = Apache->server;
    my $vhosts = 0;
    for (my $s = $server->next; $s; $s = $s->next) {
        $vhosts++;
    }
    $server->log->info("base server + $vhosts vhosts ready to run tests");
}

# testing $s->add_config()
my $conf = <<'EOC';
# must use PerlModule here to check for segfaults
PerlModule Apache::TestHandler
<Location /apache/add_config>
  SetHandler perl-script
  PerlResponseHandler Apache::TestHandler::ok1
</Location>
EOC
Apache->server->add_config([split /\n/, $conf]);

# test a directive that triggers an early startup, so we get an
# attempt to use perl's mip  early
Apache->server->add_config(['<Perl >', '1;', '</Perl>']);

# cleanup files for TestHooks::startup which can't be done from the
# test itself because the files are created at the server startup and
# the test needing these files may run more than once (t/SMOKE)
{
    require Apache::Test;
    my $dir = catdir Apache::Test::config()->{vars}->{documentroot}, 'hooks',
        'startup';
    for (<$dir/*>) {
        my $file = ($_ =~ /(.*(?:open_logs|post_config)-\d+)/);
        unlink $file;
    }
}

# this is needed for TestModperl::ithreads
# one should be able to boot ithreads at the server startup and then
# access the ithreads setup at run-time when a perl interpreter is
# running on a different native threads (testing that perl
# interpreters and ithreads aren't related to the native threads they
# are running on). This should work starting from perl-5.8.1 and higher.
use Config;
if ($] >= 5.008001 && $Config{useithreads}) {
    eval { require threads; "threads"->import() };
}

use Apache::TestTrace;
use Apache::Const -compile => qw(M_POST);

# read the posted body and send it back to the client as is
sub ModPerl::Test::pass_through_response_handler {
    my $r = shift;

    if ($r->method_number == Apache::M_POST) {
        my $data = ModPerl::Test::read_post($r);
        debug "pass_through_handler read: $data\n";
        $r->print($data);
    }

    Apache::OK;
}

use constant IOBUFSIZE => 8192;

use Apache::Const -compile => qw(MODE_READBYTES);
use APR::Const    -compile => qw(SUCCESS BLOCK_READ);

# to enable debug start with: (or simply run with -trace=debug)
# t/TEST -trace=debug -start
sub ModPerl::Test::read_post {
    my $r = shift;
    my $debug = shift || 0;

    my @data = ();
    my $seen_eos = 0;
    my $filters = $r->input_filters();
    my $ba = $r->connection->bucket_alloc;
    my $bb = APR::Brigade->new($r->pool, $ba);

    my $count = 0;
    do {
        my $rv = $filters->get_brigade($bb,
            Apache::MODE_READBYTES, APR::BLOCK_READ, IOBUFSIZE);
        if ($rv != APR::SUCCESS) {
            return $rv;
        }

        $count++;

        warn "read_post: bb $count\n" if $debug;

        while (!$bb->empty) {
            my $buf;
            my $b = $bb->first;

            $b->remove;

            if ($b->is_eos) {
                warn "read_post: EOS bucket:\n" if $debug;
                $seen_eos++;
                last;
            }

            my $status = $b->read($buf);
            if ($status != APR::SUCCESS) {
                return $status;
            }
            warn "read_post: DATA bucket: [$buf]\n" if $debug;
            push @data, $buf;
        }

        $bb->destroy;

    } while (!$seen_eos);

    return join '', @data;
}

sub ModPerl::Test::add_config {
    my $r = shift;

    #test adding config at request time
    $r->add_config(['require valid-user']);

    Apache::OK;
}

sub ModPerl::Test::exit_handler {
    my($p, $s) = @_;

    $s->log->info("Child process pid=$$ is exiting");

    Apache::OK;

}

END {
    warn "END in modperl_extra.pl, pid=$$\n";
}

package ModPerl::TestFilterDebug;

use base qw(Apache::Filter);
use Apache::FilterRec ();
use APR::Brigade ();
use APR::Bucket ();

use Apache::Const -compile => qw(OK DECLINED);
use APR::Const -compile => ':common';

# to use these functions add any or all of these filter handlers
# PerlInputFilterHandler  ModPerl::TestFilterDebug::snoop_request
# PerlInputFilterHandler  ModPerl::TestFilterDebug::snoop_connection
# PerlOutputFilterHandler ModPerl::TestFilterDebug::snoop_request
# PerlOutputFilterHandler ModPerl::TestFilterDebug::snoop_connection
#

sub snoop_connection : FilterConnectionHandler { snoop("connection", @_) }
sub snoop_request    : FilterRequestHandler    { snoop("request",    @_) }

sub snoop {
    my $type = shift;
    my($filter, $bb, $mode, $block, $readbytes) = @_; # filter args

    # $mode, $block, $readbytes are passed only for input filters
    my $stream = defined $mode ? "input" : "output";

    # read the data and pass-through the bucket brigades unchanged
    if (defined $mode) {
        # input filter
        my $rv = $filter->next->get_brigade($bb, $mode, $block, $readbytes);
        return $rv unless $rv == APR::SUCCESS;
        bb_dump($type, $stream, $bb);
    }
    else {
        # output filter
        bb_dump($type, $stream, $bb);
        my $rv = $filter->next->pass_brigade($bb);
        return $rv unless $rv == APR::SUCCESS;
    }
    #if ($bb->empty) {
    #    return -1;
    #}

    return Apache::OK;
}

sub bb_dump {
    my($type, $stream, $bb) = @_;

    my @data;
    for (my $b = $bb->first; $b; $b = $bb->next($b)) {
        $b->read(my $bdata);
        $bdata = '' unless defined $bdata;
        push @data, $b->type->name, $bdata;
    }

    # send the sniffed info to STDERR so not to interfere with normal
    # output
    my $direction = $stream eq 'output' ? ">>>" : "<<<";
    print STDERR "\n$direction $type $stream filter\n";

    unless (@data) {
        print STDERR "  No buckets\n";
        return;
    }

    my $c = 1;
    while (my($btype, $data) = splice @data, 0, 2) {
        print STDERR "    o bucket $c: $btype\n";
        print STDERR "[$data]\n";
        $c++;
    }
}

package ModPerl::TestMemoryLeak;

# handy functions to measure memory leaks. since it measures the total
# memory size of the process and not just perl leaks, you get your
# C/XS leaks discovered too
#
# For example to test TestAPR::Pool::handler for leaks, add to its
# top:
#
#  ModPerl::TestMemoryLeak::start();
#
# and just before returning from the handler add:
#
#  ModPerl::TestMemoryLeak::end();
#
# now start the server with only worker server
#
#  % t/TEST -maxclients 1 -start
#
# of course use maxclients 1 only if your test be handled with one
# client, e.g. proxy tests need at least two clients. 
#
# Now repeat the same test several times (more than 3)
#
# % t/TEST -run apr/pool -times=10
#
# t/logs/error_log will include something like:
#
#    size    vsize resident    share      rss
#    196k     132k     196k       0M     196k
#    104k     132k     104k       0M     104k
#     16k       0k      16k       0k      16k
#      0k       0k       0k       0k       0k
#      0k       0k       0k       0k       0k
#      0k       0k       0k       0k       0k
#
# as you can see the first few runs were allocating memory, but the
# following runs should consume no more memory. The leak tester measures
# the extra memory allocated by the process since the last test. Notice
# that perl and apr pools usually allocate more memory than they
# need, so some leaks can be hard to see, unless many tests (like a
# hundred) were run.

use warnings;
use strict;

# GTop v0.12 is the first version that will work under threaded mpms
use constant HAS_GTOP => eval { require GTop && GTop->VERSION >= 0.12 };

my $gtop = HAS_GTOP ? GTop->new : undef;
my @attrs = qw(size vsize resident share rss);
my $format = "%8s %8s %8s %8s %8s\n";

my %before;

sub start {

    die "No GTop avaible, bailing out" unless HAS_GTOP;

    unless (keys %before) {
        my $before = $gtop->proc_mem($$);
        %before = map { $_ => $before->$_() } @attrs;
        # print the header once
        warn sprintf $format, @attrs;
    }
}

sub end {

    die "No GTop avaible, bailing out" unless HAS_GTOP;

    my $after = $gtop->proc_mem($$);
    my %after = map {$_ => $after->$_()} @attrs;
    warn sprintf $format,
        map GTop::size_string($after{$_} - $before{$_}), @attrs;
    %before = %after;
}

1;
