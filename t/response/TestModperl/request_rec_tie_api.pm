package TestModperl::request_rec_tie_api;

use strict;
use warnings FATAL => 'all';

use Apache::RequestIO ();

use Apache::Test;
use Apache::TestUtil;
use Apache::TestConfig;

use File::Spec::Functions qw(catfile catdir);

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 3;

    ok fileno STDOUT;

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
