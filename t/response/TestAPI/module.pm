package TestAPI::module;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::Module ();
use DynaLoader ();

sub handler {
    my $r = shift;

    plan $r, tests => 6;

    my $top_module = Apache::Module->top_module;

    ok $top_module;

    ok $top_module->version;

    ok $top_module->module_index;

    ok $top_module->name;

    ok $top_module->cmds;

    for (my $modp = $top_module; $modp; $modp = $modp->next) {
        if ($modp->name eq 'mod_perl.c') {
            ok 1;
            last;
        }
    }

    0;
}

1;
