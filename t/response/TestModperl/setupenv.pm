package TestModperl::setupenv;

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use APR::Table ();

use Apache::Test;
use Apache::TestUtil;

use Apache::Const -compile => qw(OK DECLINED);

sub handler {

    my $r = shift;

    # how many different URIs will be hit?
    my $requests = $r->args;

    # $requests locations with 7 tests each
    plan $r, tests => $requests * 7;

    return Apache::OK;
}

sub env {

    my $r = shift;

    Apache::Test::init_test_pm($r);  # tie STDOUT

    (my $value) = $r->uri =~ /TestModperl__setupenv_(\w+)/;

    ok t_cmp(Apache::Test::vars('remote_addr'),
             $ENV{REMOTE_ADDR},
             'found REMOTE_ADDR in %ENV');

    ok t_cmp('server',
             $ENV{SRV_SUBPROCESS},
             'found subprocess_env table entry SRV_SUBPROCESS in %ENV');

    ok t_cmp($value,
             $ENV{DIR_SUBPROCESS},
             'found subprocess_env table entry DIR_SUBPROCESS in %ENV');

    ok t_cmp($value,
             $ENV{DIR_SETENV},
             'found per-directory SetEnv entry in %ENV');

    ok t_cmp('server',
             $ENV{SRV_SETENV},
             'found per-server SetEnv entry in %ENV');

    # PerlSetEnv always set
    ok t_cmp($value,
             $ENV{DIR_PERLSETENV},
             'found per-directory PerlSetEnv entry in %ENV');

    ok t_cmp('server',
             $ENV{SRV_PERLSETENV},
             'found per-server PerlSetEnv entry in %ENV');

    return Apache::OK;
}

sub noenv {

    my $r = shift;

    Apache::Test::init_test_pm($r);  # tie STDOUT

    (my $value) = $r->uri =~ /TestModperl__setupenv_(\w+)/;

    ok t_cmp(undef,
             $ENV{REMOTE_ADDR},
             'REMOTE_ADDR not found in %ENV');

    ok t_cmp(undef,
             $ENV{SRV_SUBPROCESS},
             'subprocess_env table entry SRV_SUBPROCESS not found in %ENV');

    ok t_cmp(undef,
             $ENV{DIR_SUBPROCESS},
             'subprocess_env table entry DIR_SUBPROCESS not found in %ENV');

    ok t_cmp(undef,
             $ENV{DIR_SETENV},
             'per-directory SetEnv entry not found in %ENV');

    ok t_cmp(undef,
             $ENV{SRV_SETENV},
             'per-server SetEnv entry not found in %ENV');

    # PerlSetEnv always set
    ok t_cmp($value,
             $ENV{DIR_PERLSETENV},
             'found per-directory PerlSetEnv entry in %ENV');

    ok t_cmp('server',
             $ENV{SRV_PERLSETENV},
             'found per-server PerlSetEnv entry in %ENV');

    return Apache::OK;
}

sub someenv {

    my $r = shift;

    Apache::Test::init_test_pm($r);  # tie STDOUT

    (my $value) = $r->uri =~ /TestModperl__setupenv_(\w+)/;

    ok t_cmp(Apache::Test::vars('remote_addr'),
             $ENV{REMOTE_ADDR},
             'found REMOTE_ADDR in %ENV');

    # set before void call
    ok t_cmp('server',
             $ENV{SRV_SUBPROCESS},
             'found subprocess_env table entry one in %ENV');

    ok t_cmp(undef,
             $ENV{DIR_SUBPROCESS},
             'subprocess_env table entry DIR_SUBPROCESS not found in %ENV');

    ok t_cmp(undef,
             $ENV{DIR_SETENV},
             'per-directory SetEnv entry not found in %ENV');

    ok t_cmp(undef,
             $ENV{SRV_SETENV},
             'per-server SetEnv entry not found in %ENV');

    # PerlSetEnv always set
    ok t_cmp($value,
             $ENV{DIR_PERLSETENV},
             'found per-directory PerlSetEnv entry in %ENV');

    ok t_cmp('server',
             $ENV{SRV_PERLSETENV},
             'found per-server PerlSetEnv entry in %ENV');

    return Apache::OK;
}

sub subenv_void {

    shift->subprocess_env;

    return Apache::OK;
}

sub subenv_one {

    shift->subprocess_env->set(SRV_SUBPROCESS => 'server');

    return Apache::OK;
}

sub subenv_two {

    my $r = shift;

    (my $value) = $r->uri =~ /TestModperl__setupenv_(\w+)/;

    $r->subprocess_env->set(DIR_SUBPROCESS => $value);

    return Apache::OK;
}

1;
__DATA__
# create a separate virtual host so we can use
# keepalives - a per-connection interpreter is
# the only way to make sure that we can plan in
# one request and test in subsequent tests
<NoAutoConfig>
<VirtualHost TestModperl::setupenv>

    KeepAlive On

    <IfDefine PERL_ITHREADS>
        PerlInterpScope connection
    </Ifdefine>

    PerlModule TestModperl::setupenv

    PerlPostReadRequestHandler TestModperl::setupenv::subenv_one

    # SetEnv is affected by +SetupEnv
    SetEnv SRV_SETENV server

    # PerlSetEnv is not affected by +SetupEnv or -SetupEnv
    # it is entirely separate and always set if configured
    PerlSetEnv SRV_PERLSETENV server

    # plan
    <Location /TestModperl__setupenv>
        SetHandler modperl
        PerlResponseHandler TestModperl::setupenv
    </Location>

    # default modperl handler
    # %ENV should not contain standard CGI variables
    # or entries from the subprocess_env table
    <Location /TestModperl__setupenv_mpdefault>
        SetHandler modperl
        PerlResponseHandler TestModperl::setupenv::noenv

        PerlFixupHandler TestModperl::setupenv::subenv_two

        SetEnv DIR_SETENV mpdefault
        PerlSetEnv DIR_PERLSETENV mpdefault
    </Location>

    # modperl handler + SetupEnv
    # %ENV should contain CGI variables as well as
    # anything put into the subprocess_env table
    <Location /TestModperl__setupenv_mpsetup>
        SetHandler modperl
        PerlResponseHandler TestModperl::setupenv::env

        PerlOptions +SetupEnv

        PerlFixupHandler TestModperl::setupenv::subenv_two

        SetEnv DIR_SETENV mpsetup
        PerlSetEnv DIR_PERLSETENV mpsetup
    </Location>

    # $r->subprocess_env in a void context with no args
    # should do the same as +SetupEnv wrt CGI variables
    # and entries already in the subprocess_env table
    # but subprocess_env entries that appear later will
    # not show up in %ENV
    <Location /TestModperl__setupenv_mpvoid>
        SetHandler modperl
        PerlResponseHandler TestModperl::setupenv::someenv

        PerlHeaderParserHandler TestModperl::setupenv::subenv_void
        PerlFixupHandler TestModperl::setupenv::subenv_two

        SetEnv DIR_SETENV mpvoid
        PerlSetEnv DIR_PERLSETENV mpvoid
    </Location>

    # +SetupEnv should always populate %ENV fully prior
    # to running the content handler (regardless of when
    # $r->subprocess_env() was called) to ensure that
    # %ENV is an accurate representation of the
    # subprocess_env table
    <Location /TestModperl__setupenv_mpsetupvoid>
        SetHandler modperl
        PerlResponseHandler TestModperl::setupenv::env

        PerlOptions +SetupEnv
    
        PerlHeaderParserHandler TestModperl::setupenv::subenv_void
        PerlFixupHandler TestModperl::setupenv::subenv_two

        SetEnv DIR_SETENV mpsetupvoid
        PerlSetEnv DIR_PERLSETENV mpsetupvoid
    </Location>

    # default perl-script handler is equivalent to +SetupEnv
    # CGI variables and subprocess_env entries will be in %ENV
    <Location /TestModperl__setupenv_psdefault>
        SetHandler perl-script
        PerlResponseHandler TestModperl::setupenv::env

        PerlFixupHandler TestModperl::setupenv::subenv_two

        SetEnv DIR_SETENV psdefault
        PerlSetEnv DIR_PERLSETENV psdefault
    </Location>

    # -SetupEnv should not put CGI variables or subprocess_env
    # entries in %ENV
    <Location /TestModperl__setupenv_psnosetup>
        SetHandler perl-script
        PerlResponseHandler TestModperl::setupenv::noenv

        PerlOptions -SetupEnv

        PerlFixupHandler TestModperl::setupenv::subenv_two

        SetEnv DIR_SETENV psnosetup
        PerlSetEnv DIR_PERLSETENV psnosetup
    </Location>

    # +SetupEnv should always populate %ENV fully prior
    # to running the content handler (regardless of when
    # $r->subprocess_env() was called) to ensure that
    # %ENV is an accurate representation of the
    # subprocess_env table
    <Location /TestModperl__setupenv_psvoid>
        SetHandler perl-script
        PerlResponseHandler TestModperl::setupenv::env

        PerlHeaderParserHandler TestModperl::setupenv::subenv_void
        PerlFixupHandler TestModperl::setupenv::subenv_two

        SetEnv DIR_SETENV psvoid
        PerlSetEnv DIR_PERLSETENV psvoid
    </Location>

    # equivalent to modperl handler with $r->subprocess_env() - 
    # CGI variables are there, but not subprocess_env entries
    # that are populated after the void call
    <Location /TestModperl__setupenv_psnosetupvoid>
        SetHandler perl-script
        PerlResponseHandler TestModperl::setupenv::someenv

        PerlOptions -SetupEnv

        PerlHeaderParserHandler TestModperl::setupenv::subenv_void
        PerlFixupHandler TestModperl::setupenv::subenv_two

        SetEnv DIR_SETENV psnosetupvoid
        PerlSetEnv DIR_PERLSETENV psnosetupvoid
    </Location>
</VirtualHost>
</NoAutoConfig>
