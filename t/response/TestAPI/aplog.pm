package TestAPI::aplog;

use strict;
use warnings FATAL => 'all';

use Apache::ServerRec qw(warn); # override warn locally
use Apache::RequestRec ();
use Apache::RequestUtil ();
use Apache::Log ();
use Apache::MPM ();

use File::Spec::Functions qw(catfile);

use Apache::Test;
use Apache::TestUtil;
use TestCommon::LogDiff;

use Apache::Const -compile => qw(OK :log);
use APR::Const    -compile => qw(:error SUCCESS);

my @LogLevels = qw(emerg alert crit error warn notice info debug);
my $package = __PACKAGE__;

my $path = catfile Apache::Test::vars('serverroot'),
    qw(logs error_log);

sub handler {
    my $r = shift;
    my $s = $r->server;

    plan $r, tests => (@LogLevels * 2) + 19;

    my $logdiff = TestCommon::LogDiff->new($path);

    my $rlog = $r->log;

    ok $rlog->isa('Apache::Log::Request');

    my $slog = $s->log;

    ok $slog->isa('Apache::Log::Server');

    t_server_log_warn_is_expected();
    $rlog->info($package, " test in progress");
    ok t_cmp $logdiff->diff,
        qr/... TestAPI::aplog test in progress/,
        '$r->log->info';

    my($file, $line) = Apache::Log::LOG_MARK;
    ok $file eq __FILE__;
    ok $line == __LINE__ - 2;

    for my $method (@LogLevels) {
        # wrap in sub {}, else Test.pm tries to run the return value
        # of ->can
        ok sub { $rlog->can($method) };
        ok sub { $slog->can($method) };
    }

    # log_serror
    {
        t_server_log_warn_is_expected();
        $s->log_serror(Apache::Log::LOG_MARK,
                       Apache::LOG_INFO|Apache::LOG_STARTUP,
                       APR::SUCCESS, "This log message comes with no header");
        ok t_cmp $logdiff->diff,
            qr/^This log message comes with no header$/m,
            '$s->log_serror(LOG_MARK, LOG_INFO|LOG_STARTUP...)';

        t_server_log_warn_is_expected();
        $s->log_serror(__FILE__, __LINE__, Apache::LOG_DEBUG,
                       APR::SUCCESS, "log_serror test 1");
        ok t_cmp $logdiff->diff,
            qr/: log_serror test 1$/m,
            '$s->log_serror(__FILE__, __LINE__, LOG_DEBUG...)';

        # the APR_EGENERAL error string changed for APR 1.0
        my $egeneral = have_min_apache_version('2.1.0')
           ? "Internal error"
           : "Error string not specified yet";

        t_server_log_warn_is_expected();
        $s->log_serror(Apache::Log::LOG_MARK, Apache::LOG_DEBUG,
                       APR::EGENERAL, "log_serror test 2");
        ok t_cmp $logdiff->diff,
            qr/$egeneral: log_serror test 2/,
            '$s->log_serror(LOG_MARK, LOG_DEBUG, APR::EGENERAL...)';
    }

    # log_rerror
    t_server_log_error_is_expected();
    $r->log_rerror(Apache::Log::LOG_MARK, Apache::LOG_CRIT,
                   APR::ENOTIME, "log_rerror test");
    # can't match against the error string, since a locale may kick in
    ok t_cmp $logdiff->diff,
        qr/\[crit\] .*?: log_rerror test/,
        '$r->log_rerror(LOG_MARK, LOG_CRIT, APR::ENOTIME...)';

    # log_error
    {
        t_server_log_error_is_expected();
        $r->log_error('$r->log_error test');
        ok t_cmp $logdiff->diff,
            qr/\[error\] \$r->log_error test/,
            '$r->log_error(...)';

        t_server_log_error_is_expected();
        $s->log_error('$s->log_error test');
        ok t_cmp $logdiff->diff,
            qr/\[error\] \$s->log_error test/,
            '$s->log_error(...)';
    }
    
    # log_reason
    {
        t_server_log_error_is_expected();
        $r->log_reason('$r->log_reason test');
        ok t_cmp $logdiff->diff,
            qr/\[error\] access to.*failed.*reason: \$r->log_reason test/,
            '$r->log_reason(msg)';
        
        t_server_log_error_is_expected();
        $r->log_reason('$r->log_reason filename test','filename');
        ok t_cmp $logdiff->diff,
            qr/\[error\] access to filename failed.*\$r->log_reason filename test/,
            '$r->log_reason(msg, filename)';
    }

    # XXX: at the moment we can't change loglevel after server startup
    # in a threaded mpm environment
    if (!Apache::MPM->is_threaded) {
        $s->loglevel(Apache::LOG_INFO);

        if ($s->error_fname) {
            #XXX: does not work under t/TEST -ssl
            $slog->debug(sub { die "set loglevel no workie" });
            # ok t_cmp $logdiff->diff...
        }

        t_server_log_warn_is_expected();
        $s->loglevel(Apache::LOG_DEBUG);
        $slog->debug(sub { ok 1; "$package test done" });
        ok t_cmp $logdiff->diff,
            qr/TestAPI::aplog test done/,
            '$slog->debug(sub { })';

    }
    else {
        ok 1;
        ok 1;
    }

    t_server_log_warn_is_expected();
    $s->warn('$s->warn test');
    ok t_cmp $logdiff->diff,
        qr/\[warn\] \$s->warn test/,
        '$s->warn()';

    {
        t_server_log_warn_is_expected();
        # this uses global server to get $s internally
        Apache::ServerRec::warn("Apache::ServerRec::warn test");
        ok t_cmp $logdiff->diff,
            qr/\[warn\] Apache::ServerRec::warn test/,
            'Apache::ServerRec::warn() w/o Apache->request ';

        Apache->request($r);
        t_server_log_warn_is_expected();
        # this uses the global $r to get $s internally
        Apache::ServerRec::warn("Apache::ServerRec::warn test");
        ok t_cmp $logdiff->diff,
            qr/\[warn\] Apache::ServerRec::warn test/,
            'Apache::ServerRec::warn() w/ Apache->request ';
    }

    t_server_log_warn_is_expected();
    warn "warn test";
    ok t_cmp $logdiff->diff,
        qr/\[warn\] warn test/,
        'overriden via export warn()';

    Apache::OK;
}

1;
