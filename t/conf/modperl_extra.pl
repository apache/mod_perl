##########################################################
### IMPORTANT: only things that must be run absolutely ###
### during the config phase should be in this file     ###
##########################################################

use strict;
use warnings FATAL => 'all';

die '$ENV{MOD_PERL} not set!' unless $ENV{MOD_PERL};

use File::Spec::Functions qw(canonpath catdir);

use Apache2 ();

use Apache::ServerUtil ();
use Apache::ServerRec ();
use Apache::Process ();
use Apache::Log ();

use Apache::Const -compile => ':common';

reorg_INC();

register_post_config_startup();

startup_info();

test_add_config();

test_add_version_component();

test_apache_status();

test_hooks_startup();

test_modperl_env();

test_method_obj();

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

sub register_post_config_startup {
    my $s = Apache->server;
    my $pool = $s->process->pool;
    my $t_conf_path = Apache::ServerUtil::server_root_relative($pool,
                                                               "conf");

    # most of the startup code needs to be run at the post_config
    # phase
    $s->push_handlers(PerlPostConfigHandler => sub {
        require "$t_conf_path/post_config_startup.pl"; Apache::OK });
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

sub test_modperl_env {
    # see t/response/TestModperl/env.pm
    $ENV{MODPERL_EXTRA_PL} = __FILE__;
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

    Apache::OK;
}

1;
