##########################################################
### this file contains code that should be run on the  ###
### server startup but not during the config phase     ###
##########################################################
use strict;
use warnings FATAL => 'all';

use Socket (); # test DynaLoader vs. XSLoader workaround for 5.6.x

use Apache::ServerRec ();
use Apache::ServerUtil ();
use Apache::Process ();
use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::RequestUtil ();
use Apache::Connection ();
use Apache::Log ();

use APR::Table ();
use APR::Pool ();

use ModPerl::Util (); #for CORE::GLOBAL::exit

# would be nice to write a real test, but for now just see that we can
# load it:
use Apache::SizeLimit ();

use Apache::Const -compile => ':common';

END {
    warn "END in modperl_extra.pl, pid=$$\n";
}

test_loglevel();

test_apache_resource();

test_perl_ithreads();

test_server_shutdown_cleanup_register();

### only subs below this line ###


# test startup loglevel setting (under threaded mpms loglevel can be
# changed only before threads are started) so here we test whether we
# can still set it after restart
sub test_loglevel {
    use Apache::Const -compile => 'LOG_INFO';
    my $s = Apache->server;
    my $oldloglevel = $s->loglevel(Apache::LOG_INFO);
    # restore
    $s->loglevel($oldloglevel);
}

sub test_apache_resource {
    ### Apache::Resource tests

    # load first for the menu
    require Apache::Status;

    # uncomment for local tests
    #$ENV{PERL_RLIMIT_DEFAULTS} = 1;
    #$Apache::Resource::Debug   = 1;

    # requires optional BSD::Resource
    return unless eval { require BSD::Resource };

    require Apache::Resource;
}


sub test_perl_ithreads {
    # this is needed for TestPerl::ithreads
    # one should be able to boot ithreads at the server startup and
    # then access the ithreads setup at run-time when a perl
    # interpreter is running on a different native threads (testing
    # that perl interpreters and ithreads aren't related to the native
    # threads they are running on). This should work starting from
    # perl-5.8.1 and higher.
    use Config;
    if ($] >= 5.008001 && $Config{useithreads}) {
        eval { require threads; "threads"->import() };
    }
}

sub test_server_shutdown_cleanup_register {
    # we can't really test the functionality since it happens at
    # server shutdown, when the test suite has finished its run
    # so just check that we can register the cleanup and that it
    # doesn't segfault
    Apache::ServerUtil::server_shutdown_cleanup_register(sub { Apache::OK });

    # replace the sub with the following to get some visual debug
    # should log cnt:1 on -start, oncand cnt: 2 -stop followed by cnt: 1)
    #Apache::ServerUtil::server_shutdown_cleanup_register( sub {
    #    my $cnt = Apache::ServerUtil::restart_count();
    #    open my $fh, ">>/tmp/out" or die "$!";
    #    print $fh "cnt: $cnt\n";
    #    close $fh;
    #});
}

sub ModPerl::Test::exit_handler {
    my($p, $s) = @_;

    $s->log->info("Child process pid=$$ is exiting");

    Apache::OK;

}


1;
