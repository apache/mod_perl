package TestPerl::signals;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::MPM ();

use POSIX qw(SIGALRM);

use Apache::Const -compile => qw(OK);

my $mpm = lc Apache::MPM->show;

# XXX: ALRM sighandler works with prefork, but it doesn't work with
# worker (others?)

sub handler {
    my $r = shift;

    plan $r, tests => 2,
        need { "works for prefork" => ($mpm eq 'prefork') };

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

    {
        eval {
            POSIX::sigaction(SIGALRM,
                             POSIX::SigAction->new(sub { die "alarm" }))
                  or die "Error setting SIGALRM handler: $!\n";
            alarm 2;
            run_for_5_sec();
            alarm 0;
        };
        ok t_cmp $@, qr/alarm/, "SIGALRM / POSIX";
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
