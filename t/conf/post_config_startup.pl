##########################################################
### this file contains code that should be run on the  ###
### server startup but not during the config phase     ###
##########################################################
use strict;
use warnings FATAL => 'all';

use Socket (); # test DynaLoader vs. XSLoader workaround for 5.6.x

use Apache2::ServerRec ();
use Apache2::ServerUtil ();
use Apache2::Process ();
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();
use Apache2::Connection ();
use Apache2::Log ();

use APR::Table ();
use APR::Pool ();

use ModPerl::Util (); #for CORE::GLOBAL::exit

use Apache2::Const -compile => ':common';

END {
    warn "END in modperl_extra.pl, pid=$$\n";
}

test_apache_resource();

test_apache_size_limit();

test_apache_status();

test_loglevel();

test_perl_ithreads();

test_server_shutdown_cleanup_register();

test_method_obj();



### only subs below this line ###

sub test_apache_resource {
    ### Apache2::Resource tests

    # load first for the menu
    require Apache2::Status;

    # uncomment for local tests
    #$ENV{PERL_RLIMIT_DEFAULTS} = 1;
    #$Apache2::Resource::Debug   = 1;

    # requires optional BSD::Resource
    return unless eval { require BSD::Resource };

    require Apache2::Resource;
}

sub test_apache_size_limit {
    # would be nice to write a real test, but for now just see that we
    # can load it for non-threaded mpms on supported platforms
    require Apache2::MPM;
    return if Apache2::MPM->is_threaded;
    eval { require Apache2::SizeLimit };
    if ($@) {
        # unsupported platform
        die $@ unless $@ =~ /Apache2::SizeLimit not implemented on/
            or $@ =~ /you must install BSD::Resource/;
    }
}

sub test_apache_status {
    ### Apache2::Status tests
    require Apache2::Status;
    require Apache2::Module;
    Apache2::Status->menu_item(
       'test_menu' => "Test Menu Entry",
       sub {
           my($r) = @_;
           return ["This is just a test entry"];
       }
    ) if Apache2::Module::loaded('Apache2::Status');
}

# test startup loglevel setting (under threaded mpms loglevel can be
# changed only before threads are started) so here we test whether we
# can still set it after restart
sub test_loglevel {
    use Apache2::Const -compile => 'LOG_INFO';
    my $s = Apache2::ServerUtil->server;
    my $oldloglevel = $s->loglevel(Apache2::Const::LOG_INFO);
    # restore
    $s->loglevel($oldloglevel);
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
    Apache2::ServerUtil::server_shutdown_cleanup_register(sub { Apache2::Const::OK });

    # replace the sub with the following to get some visual debug
    # should log cnt:1 on -start, oncand cnt: 2 -stop followed by cnt: 1)
    #Apache2::ServerUtil::server_shutdown_cleanup_register( sub {
    #    my $cnt = Apache2::ServerUtil::restart_count();
    #    open my $fh, ">>/tmp/out" or die "$!";
    #    print $fh "cnt: $cnt\n";
    #    close $fh;
    #});
}

sub ModPerl::Test::exit_handler {
    my($p, $s) = @_;

    $s->log->info("Child process pid=$$ is exiting");

    Apache2::Const::OK;

}

sub test_method_obj {
    # see t/modperl/methodobj
    require TestModperl::methodobj;
    $TestModperl::MethodObj = TestModperl::methodobj->new;
}

sub ModPerl::Test::add_config {
    my $r = shift;

    #test adding config at request time
    $r->add_config(['require valid-user']);

    Apache2::Const::OK;
}

1;
