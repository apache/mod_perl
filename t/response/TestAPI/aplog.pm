package TestAPI::aplog;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::Log ();
use Apache::RequestRec ();

use Apache::Const -compile => qw(OK :log);
use APR::Const    -compile => qw(:error SUCCESS);

my @LogLevels = qw(emerg alert crit error warn notice info debug);
my $package = __PACKAGE__;

sub handler {
    my $r = shift;
    my $s = $r->server;

    plan $r, tests => (@LogLevels * 2) + 5;

    my $rlog = $r->log;

    ok $rlog->isa('Apache::Log::Request');

    my $slog = $s->log;

    ok $slog->isa('Apache::Log::Server');

    $rlog->info($package, " test in progress");

    my($file, $line) = Apache::LOG_MARK;
    ok $file eq __FILE__;
    ok $line == __LINE__ - 2;

    for my $method (@LogLevels) {
        #wrap in sub {}, else Test.pm tries to run the return value of ->can
        ok sub { $rlog->can($method) };
        ok sub { $slog->can($method) };
    }

    $s->log_serror(Apache::LOG_MARK, Apache::LOG_INFO|Apache::LOG_STARTUP,
                   APR::SUCCESS, "This log message comes with no header");

    t_server_log_warn_is_expected();
    $s->log_serror(__FILE__, __LINE__, Apache::LOG_DEBUG,
                   APR::SUCCESS, "log_serror test ok");

    t_server_log_warn_is_expected();
    $s->log_serror(Apache::LOG_MARK, Apache::LOG_DEBUG,
                   APR::EGENERAL, "log_serror test 2 ok");

    t_server_log_error_is_expected();
    $r->log_rerror(Apache::LOG_MARK, Apache::LOG_CRIT,
                   APR::ENOTIME, "log_rerror test ok");

    t_server_log_error_is_expected();
    $r->log_error('$r->log_error test ok');

    t_server_log_error_is_expected();
    $s->log_error('$s->log_error test ok');

    $s->loglevel(Apache::LOG_INFO);

    if ($s->error_fname) {
        #XXX: does not work under t/TEST -ssl
        $slog->debug(sub { die "set loglevel no workie" });
    }

    $s->loglevel(Apache::LOG_DEBUG);
    $slog->debug(sub { ok 1; "$package test done" });

    Apache->warn("Apache->warn test ok");
    $s->warn('$s->warn test ok');

    Apache::OK;
}

1;
