package TestModules::reload;

use strict;
use warnings FATAL => 'all';

use ModPerl::Util ();

use Apache::Const -compile => qw(OK);

my $package = 'Apache::Reload::Test';

sub handler {
    my $r = shift;

    if ($r->args eq 'last') {
        Apache::Reload->unregister_module($package);
        ModPerl::Util::unload_package($package);
        $r->print("unregistered OK");
        return Apache::OK;
    }

    eval "use $package";

    Apache::Reload::Test::run($r);

    return Apache::OK;
}

1;
__END__

PerlModule Apache::Reload
PerlInitHandler Apache::TestHandler::same_interp_fixup Apache::Reload
PerlSetVar ReloadDebug Off
PerlSetVar ReloadAll Off
