
package TestAPI::command;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::Command ();
use Apache::Module ();

use Apache::Const -compile => qw(OK ITERATE OR_ALL);

sub handler {
    my $r = shift;

    plan $r, tests => 6;

    my $mod_perl_module = Apache::Module::find_linked_module('mod_perl.c');

    ok $mod_perl_module;

    my $cmd = $mod_perl_module->cmds;

    ok defined $cmd;

    ok UNIVERSAL::isa($cmd, 'Apache::Command');

    while ($cmd) {
        if ($cmd->name eq 'PerlResponseHandler') {
            ok t_cmp($cmd->args_how, Apache::ITERATE, 'args_how');
            ok t_cmp($cmd->errmsg, qr/Subroutine name/, 'errmsg');
            ok t_cmp($cmd->req_override, Apache::OR_ALL, 'req_override');
            last;
        }
        $cmd = $cmd->next;
    }

    Apache::OK;
}

1;
