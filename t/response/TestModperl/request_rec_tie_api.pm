package TestModperl::request_rec_tie_api;

# this test is relevant only when the tied STDIN/STDOUT are used (when
# $Config{useperlio} is not defined.)

use strict;
use warnings FATAL => 'all';

use Apache::RequestIO ();

use Apache::Test;
use Apache::TestUtil;
use Apache::TestConfig;

use File::Spec::Functions qw(catfile catdir);

use Apache::Const -compile => 'OK';

use Config;

sub handler {
    my $r = shift;

    require Apache::Build;
    my @todo;
    push @todo, 1 if Apache::Build::AIX();
    plan $r, tests => 3, todo => \@todo,
        have { "perl $]: PerlIO is used instead of TIEd IO"
                   => !($] >= 5.008 && $Config{useperlio}) };

    # XXX: on AIX 4.3.3 we get:
    #                     STDIN STDOUT STDERR
    # perl    :               0      1      2
    # mod_perl:               0      0      2
    my $fileno = fileno STDOUT;
    ok $fileno;
    t_debug "fileno STDOUT: $fileno";

    {
        my $vars = Apache::Test::config()->{vars};
        my $target_dir = catdir $vars->{serverroot}, 'logs';
        my $file = catfile $target_dir, "stdout";

        # test OPEN
        my $received = open STDOUT, ">", $file or die "Can't open $file: $!";
        ok t_cmp(1, $received, "OPEN");

        # test CLOSE, which is a noop
        ok $r->CLOSE;
        close $file;

        # restore the tie
        tie *STDOUT, $r;

        # flush things that went into the file as STDOUT
        open my $fh, $file or die "Can't open $file: $!";
        local $\;
        print <$fh>;

        # cleanup
        unlink $file;
    }

    return Apache::OK;
}

1;
