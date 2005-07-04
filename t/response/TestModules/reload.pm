package TestModules::reload;

use strict;
use warnings FATAL => 'all';

use ModPerl::Util ();

use Apache2::Const -compile => qw(OK);

my $package = 'Apache2::Reload::Test';

our $pass = 0;

sub handler {
    my $r = shift;
    $pass++;
    if ($r->args eq 'last') {
        Apache2::Reload->unregister_module($package);
        ModPerl::Util::unload_package($package);
        $pass = 0;
        $r->print("unregistered OK");
        return Apache2::Const::OK;
    }

    eval "use $package";

    Apache2::Reload::Test::run($r);

    return Apache2::Const::OK;
}

#This one shouldn't be touched
package Apache2::Reload::Test::SubPackage;

sub subpackage { 
    if ($TestModules::reload::pass == '2') {
        return 'subpackage';
    }
    else {
        return 'SUBPACKAGE';
    }
}

1;
__END__

PerlModule Apache2::Reload
PerlInitHandler Apache::TestHandler::same_interp_fixup Apache2::Reload
PerlSetVar ReloadDebug Off
PerlSetVar ReloadAll Off
