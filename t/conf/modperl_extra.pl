use strict;
use warnings FATAL => 'all';

use Socket (); # test DynaLoader vs. XSLoader workaround for 5.6.x
use IO::File ();
use File::Spec::Functions qw(canonpath catdir);

use Apache2 ();

use Apache::ServerRec ();
use Apache::ServerUtil ();
use Apache::Process ();
use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::RequestUtil ();
use Apache::Connection ();
use Apache::Log ();

use APR::Table ();

use ModPerl::Util (); #for CORE::GLOBAL::exit

use Apache::Const -compile => ':common';
use APR::Const    -compile => ':common';

reorg_INC();

die '$ENV{MOD_PERL} not set!' unless $ENV{MOD_PERL};

END {
    warn "END in modperl_extra.pl, pid=$$\n";
}

startup_info();

test_add_config();

test_hooks_startup();

test_method_obj();

test_modperl_env();

test_loglevel();

test_add_version_component();

test_apache_status();

test_apache_resource();

test_perl_ithreads();

test_base_server_pool();



### only subs below this line ###

sub reorg_INC {
    # after Apache2 has pushed blib and core dirs including Apache2 on
    # top reorg @INC to have first devel libs, then blib libs, and
    # only then perl core libs
    my $pool = Apache->server->process->pool;
    my $project_root = canonpath
        Apache::ServerUtil::server_root_relative($pool, "..");
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
}

sub test_method_obj {
    # see t/modperl/methodobj
    use TestModperl::methodobj ();
    $TestModperl::MethodObj = TestModperl::methodobj->new;
}

sub test_modperl_env {
    # see t/response/TestModperl/env.pm
    $ENV{MODPERL_EXTRA_PL} = __FILE__;
}

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

sub startup_info {
    my $ap_mods  = scalar grep { /^Apache/ } keys %INC;
    my $apr_mods = scalar grep { /^APR/    } keys %INC;

    Apache::Log->info("$ap_mods Apache:: modules loaded");
    Apache::ServerRec->log->info("$apr_mods APR:: modules loaded");

    my $server = Apache->server;
    my $vhosts = 0;
    for (my $s = $server->next; $s; $s = $s->next) {
        $vhosts++;
    }

    $server->log->info("base server + $vhosts vhosts ready to run tests");
}


sub test_add_config {
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
    # attempt to use perl's mip early
    Apache->server->add_config(['<Perl >', '1;', '</Perl>']);
}

# cleanup files for TestHooks::startup which can't be done from the
# test itself because the files are created at the server startup and
# the test needing these files may run more than once (t/SMOKE)
sub test_hooks_startup {
    require Apache::Test;
    my $dir = catdir Apache::Test::vars('documentroot'), qw(hooks startup);
    for (<$dir/*>) {
        my $file = ($_ =~ /(.*(?:open_logs|post_config)-\d+)/);
        unlink $file;
    }
}

sub test_add_version_component {
    Apache->server->push_handlers(
        PerlPostConfigHandler => \&add_my_version);

    sub add_my_version {
        my($conf_pool, $log_pool, $temp_pool, $s) = @_;
        $s->add_version_component("world domination series/2.0");
        return Apache::OK;
    }
}

sub test_apache_status {
    ### Apache::Status tests
    require Apache::Status;
    require Apache::Module;
    Apache::Status->menu_item(
       'test_menu' => "Test Menu Entry",
       sub {
           my($r, $q) = @_; #request and CGI objects
           return ["This is just a test entry"];
       }
    ) if Apache::Module::loaded('Apache::Status');
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

sub test_base_server_pool {
    # we can't really test the functionality since it happens at
    # server shutdown, when the test suite has finished its run
    # so just check that we can register the cleanup and that it
    # doesn't segfault
    my $base_server_pool = Apache::ServerUtil::base_server_pool();
    $base_server_pool->cleanup_register(sub { Apache::OK });
    # replace the sub with the following to get some visual debug
    # should log the date twice (once on -start, once more on -stop)
    # sub { local %ENV; qx[/bin/date >> /tmp/date]; Apache::OK; }
    #
    # also remember that cleanup_register() called on this pool will
    # work only when registered at the server startup
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

1;
