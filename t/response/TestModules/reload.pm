package TestModules::reload;

use strict;
use warnings FATAL => 'all';

use ModPerl::Util ();

use Apache2::Const -compile => qw(OK);

my $package = 'Apache2::Reload::Test';

sub handler {
    my $r = shift;

    if ($r->args eq 'last') {
        Apache2::Reload->unregister_module($package);
        ModPerl::Util::unload_package($package);
        $r->print("unregistered OK");
        return Apache2::Const::OK;
    }

    eval "use $package";

    Apache2::Reload::Test::run($r);

    return Apache2::Const::OK;
}

1;
__END__

PerlModule Apache2::Reload
PerlInitHandler Apache::TestHandler::same_interp_fixup Apache2::Reload
PerlSetVar ReloadDebug Off
PerlSetVar ReloadAll Off
