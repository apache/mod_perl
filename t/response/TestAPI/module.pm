
package TestAPI::module;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestConfig;
use Apache::TestUtil;
use Apache::BuildConfig;

use Apache::Module ();
use DynaLoader ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    my $cfg = Apache::Test::config();

    my $top_module = Apache::Module->top_module;

    #no promise that mod_perl will be the top_module
    my $top_module_name = (defined $top_module && $top_module->name()) || '';

    my $tests = 11;
    $tests += 3 if $top_module_name eq 'mod_perl.c';

    plan $r, tests => $tests;

    t_debug "top_module: $top_module_name";
    ok $top_module;

    ok t_cmp($top_module->version,
             $cfg->{httpd_info}->{MODULE_MAGIC_NUMBER_MAJOR},
             q{$top_module->version});

    ok t_cmp($top_module->module_index,
             scalar(keys %{ $cfg->{modules} }),
             q{$top_module->module_index})
        || 1; # the A-T config could be wrong

    #XXX: some of these tests will fail if modperl is linked static
    #rather than dso.

    if ($top_module_name eq 'mod_perl.c') {
        ok t_cmp($top_module_name, 'mod_perl.c', q{$top_module->name}) || 1;

        my $cmd = $top_module->cmds;

        ok defined $cmd;

        ok UNIVERSAL::isa($cmd, 'Apache::Command');
    }

    if (0) { #XXX: currently fails with --enable-mods-shared=all
        local $cfg->{modules}->{'mod_perl.c'} = 1;
        my $modules = {};

        for (my $modp = $top_module; $modp; $modp = $modp->next) {
            if ($modp && $modp->name) {
                $modules->{$modp->name} = 1;
            }
        }

        my %alias = (
            'sapi_apache2.c' => 'mod_php4.c',
        );

        while (my($key, $val) = each %alias) {
            next unless $modules->{$key};
            delete $modules->{$key};
            $modules->{$val} = 1;
        }

        ok t_cmp($modules, $cfg->{modules}, "Modules list");
    }

    #.c
    ok t_cmp(Apache::Module::loaded('mod_perl.c'), 1,
             "Apache::Module::loaded('mod_perl.c')");

    ok t_cmp(Apache::Module::loaded('Apache__Module_foo.c'), 0,
             "Apache::Module::loaded('Apache__Module_foo.c')");

    #.so
    {
        my $build = Apache::BuildConfig->new;
        my $expect = $build->{MODPERL_LIB_SHARED} ? 1 : 0;
        ok t_cmp(Apache::Module::loaded('mod_perl.so'), $expect,
                 "Apache::Module::loaded('mod_perl.so')");
    }

    ok t_cmp(Apache::Module::loaded('Apache__Module__foo.so'), 0,
             "Apache::Module::loaded('Apache__Module_foo.so')");

    #perl
    ok t_cmp(Apache::Module::loaded('Apache::Module'), 1,
             "Apache::Module::loaded('Apache::Module')");

    ok t_cmp(Apache::Module::loaded('Apache__Module_foo'), 0,
             "Apache::Module::loaded('Apache__Module_foo')");

    #bogus
    ok t_cmp(Apache::Module::loaded('Apache__Module_foo.foo'), 0,
             "Apache::Module::loaded('Apache__Module_foo.foo')");

    ok t_cmp(Apache::Module::loaded(''), 0,
             "Apache::Module::loaded('')");

    Apache::OK;
}

1;
