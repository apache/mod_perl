package Apache::ModuleConfig;
use strict;
$Apache::ModuleConfig::VERSION = "0.01";

unless(defined &bootstrap) {
    require DynaLoader;
    @Apache::ModuleConfig::ISA = qw(DynaLoader);
}

if($ENV{MOD_PERL}) {
    __PACKAGE__->bootstrap;
}

1;

__END__

