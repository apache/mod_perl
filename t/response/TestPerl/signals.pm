package TestPerl::signals;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::MPM ();

use POSIX qw(SIGALRM);

#use POSIX ':signal_h';

use Apache::Const -compile => qw(OK);

my $mpm = lc Apache::MPM->show;

# signal handlers don't work anywhere but with prefork, since signals
# and threads don't mix

sub handler {
    my $r = shift;

    plan $r, tests => 2,
        need { "works only for prefork" => ($mpm eq 'prefork') };

    {
        local $ENV{PERL_SIGNALS} = "unsafe";

        eval {
            local $SIG{ALRM} = sub { die "alarm" };
            alarm 2;
            run_for_5_sec();
            alarm 0;
        };
        ok t_cmp $@, qr/alarm/, "SIGALRM / unsafe %SIG";
    }

    # POSIX::sigaction doesn't work under 5.6.x
    if ($] >= 5.008) {
        my $mask = POSIX::SigSet->new( SIGALRM );
        my $action = POSIX::SigAction->new(sub { die "alarm" }, $mask);
        my $oldaction = POSIX::SigAction->new();
        POSIX::sigaction(SIGALRM, $action, $oldaction );
        eval {
            alarm 2;
            run_for_5_sec();
            alarm 0;
        };
        POSIX::sigaction(SIGALRM, $oldaction); # restore original

        ok t_cmp $@, qr/alarm/, "SIGALRM / POSIX";
    }
    else {
        skip "POSIX::sigaction doesn't work under 5.6.x", 0;
    }

    return Apache::OK;
}

sub run_for_5_sec {
    for (1..20) { # ~5 sec
        my $x = 3**20;
        select undef, undef, undef, 0.25;
    }
}

1;

__END__
