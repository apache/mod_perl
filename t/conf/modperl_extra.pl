use Socket (); #test DynaLoader vs. XSLoader workaround for 5.6.x
use IO::File ();
use File::Spec::Functions qw(canonpath);

use Apache2 ();

use Apache::Server ();
use Apache::ServerUtil ();
use Apache::Process ();

# after Apache2 has pushed blib and core dirs including Apache2 on top
# reorg @INC to have first devel libs, then blib libs, and only then
# perl core libs
my $pool = Apache->server->process->pool;
my $project_root = canonpath Apache::server_root_relative($pool, "..");
my (@a, @b, @c);
for (@INC) {
    if (m|^$project_root|) {
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


# this is needed for TestModperl::ithreads
# one should be able to boot ithreads at the server startup and then
# access the ithreads setup at run-time when a perl interpreter is
# running on a different native threads (testing that perl
# interpreters and ithreads aren't related to the native threads they
# are running on). This should work starting from perl-5.8.1 and higher.
use Config;
if ($] >= 5.008001 && $Config{useithreads}) {
    eval { require threads; threads->import() };
}


use constant IOBUFSIZE => 8192;

use Apache::Const -compile => qw(MODE_READBYTES);
use APR::Const    -compile => qw(SUCCESS BLOCK_READ);

sub ModPerl::Test::read_post {
    my $r = shift;
    my $debug = shift || 0;

    my @data = ();
    my $seen_eos = 0;
    my $filters = $r->input_filters();
    my $ba = $r->connection->bucket_alloc;
    my $bb = APR::Brigade->new($r->pool, $ba);

    do {
        my $rv = $filters->get_brigade($bb,
            Apache::MODE_READBYTES, APR::BLOCK_READ, IOBUFSIZE);
        if ($rv != APR::SUCCESS) {
            return $rv;
        }

        while (!$bb->empty) {
            my $buf;
            my $b = $bb->first;

            $b->remove;

            if ($b->is_eos) {
                warn "EOS bucket:\n" if $debug;
                $seen_eos++;
                last;
            }

            my $status = $b->read($buf);
            warn "DATA bucket: [$buf]\n" if $debug;
            if ($status != APR::SUCCESS) {
                return $status;
            }
            push @data, $buf;
        }

        $bb->destroy;

    } while (!$seen_eos);

    return join '', @data;
}

sub ModPerl::Test::add_config {
    my $r = shift;

    #test adding config at request time
    my $errmsg = $r->add_config(['require valid-user']);
    die $errmsg if $errmsg;

    Apache::OK;
}

sub ModPerl::Test::exit_handler {
    my($p, $s) = @_;

    $s->log->info("Child process pid=$$ is exiting");
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


1;
