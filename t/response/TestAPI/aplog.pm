package TestAPI::aplog;

use strict;
use warnings FATAL => 'all';

use Apache::Log ();
use Apache::Test;
use Apache::Const -compile => ':log';
use APR::Const -compile => ':error';

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

    $s->log_serror(Apache::LOG_MARK, Apache::LOG_DEBUG, 0,
                   "log_serror test ok");

    $s->log_serror(Apache::LOG_MARK, Apache::LOG_DEBUG,
                   APR::ENOTIME, "log_serror test 2 ok");

    $r->log_rerror(Apache::LOG_MARK, Apache::LOG_DEBUG|Apache::LOG_NOERRNO,
                   APR::ENOTIME, "log_rerror test ok");

    $r->log_error('$r->log_error test ok');
    $s->log_error('$s->log_error test ok');

    $s->loglevel(Apache::LOG_INFO);

    if ($s->error_fname) {
        #XXX: does not work under t/TEST -ssl
        $slog->debug(sub { die "set loglevel no workie" });
    }

    $s->loglevel(Apache::LOG_DEBUG);
    $slog->debug(sub { ok 1; "$package test done" });

    Apache::OK;
}

1;
