package TestAPI::aplog;

use strict;
use warnings FATAL => 'all';

use Apache::Log ();
use Apache::Test;

my @LogLevels = qw(emerg alert crit error warn notice info debug);
my $package = __PACKAGE__;

sub handler {
    my $r = shift;

    plan $r, tests => (@LogLevels * 2) + 3;

    my $rlog = $r->log;

    ok $rlog->isa('Apache::Log::Request');

    my $slog = $r->server->log;

    ok $slog->isa('Apache::Log::Server');

    $rlog->info($package, " test in progress");

    for my $method (@LogLevels) {
        #wrap in sub {}, else Test.pm tries to run the return value of ->can
        ok sub { $rlog->can($method) };
        ok sub { $slog->can($method) };
    }

    $slog->info(sub { ok 1; "$package test done" });

    Apache::OK;
}

1;
