
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

    my $module_count = 0;
    for (my $modp = $top_module; $modp; $modp = $modp->next) {
        $module_count++;
    }

    my $tests = 10 + ( 5 * $module_count );

    plan $r, tests => $tests;

    my $core = Apache::Module::find_linked_module('core.c');
    ok defined $core && $core->name eq 'core.c';

    #.c
    ok t_cmp(Apache::Module::loaded('mod_perl.c'), 1,
             "Apache::Module::loaded('mod_perl.c')");

    ok t_cmp(Apache::Module::loaded('Apache__Module_foo.c'), 0,
             "Apache::Module::loaded('Apache__Module_foo.c')");

    #.so
    {
        my $build = Apache::BuildConfig->new;
        my $expect = $build->should_build_apache ? 0 : 1;
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

    ok t_cmp ref($top_module), 'Apache::Module', 'top_module';

    my $mmn_major = $cfg->{httpd_info}{MODULE_MAGIC_NUMBER_MAJOR};
    my $mmn_minor = $cfg->{httpd_info}{MODULE_MAGIC_NUMBER_MINOR};
    for (my $modp = $top_module; $modp; $modp = $modp->next) {
        my $name = $modp->name;
        ok $name;
        t_debug("Testing module: " . $modp->name);
        ok $modp->version == $mmn_major;
        ok $modp->minor_version <= $mmn_minor;
        ok $modp->module_index >= 0;
        my $cmds = $modp->cmds;
        ok !defined($cmds) || ref($cmds) eq 'Apache::Command';
    }

    Apache::OK;
}

1;
