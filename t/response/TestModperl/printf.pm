package TestModperl::printf;

use strict;
use warnings FATAL => 'all';

use Apache::RequestIO ();
use Apache::RequestRec ();
use APR::Table ();

use Apache::Const -compile => qw(OK LOG_ERR);

sub handler {
    my $r = shift;

    my $tests = 4;

    $r->printf("1..%d\n", $tests);

    # ok 1
    $r->printf("ok");
    $r->printf(" %d\n", 1);

    # ok 2
    my $fmt = "%s%s %d\n";
    $r->printf($fmt, qw(o k), 2);

    # ok 3
    my @a = ("ok %d%c", 3, ord("\n"));
    $r->PRINTF(@a);

    # ok 4 (gets input from the fixup handler via notes)
    {
        my $note = $r->notes->get("fixup") || '';
        my $ok = $note =~ 
            /\$r->printf can't be called before the response phase/;
        $r->print("not ") unless $ok;
        $r->print("ok 4\n");
        $r->print("# either fixup was successful at printing to the\n",
                  "# client (which shouldn't happen before the\n",
                  "# response phase), or the note was lost/never set\n")
            unless $ok;
        $r->notes->clear;
    }

    Apache::OK;
}

sub fixup {
    my $r = shift;

    # it's not possible to send a response body before the response
    # phase
    eval { $r->printf("whatever") };
    $r->notes->set(fixup => "$@") if $@;

    Apache::OK;
}

1;
__END__
PerlModule TestModperl::printf
PerlFixupHandler TestModperl::printf::fixup
